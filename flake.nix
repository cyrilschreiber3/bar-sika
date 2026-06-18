{
  description = "bar-sika application using uv2nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    pyproject-nix,
    uv2nix,
    pyproject-build-systems,
    ...
  }:
    {
      nixosModules.default = import ./nixos-module.nix;

      overlays.default = final: prev: {
        bar-sika = self.packages.${final.stdenv.hostPlatform.system}.default;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        inherit (nixpkgs) lib;

        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python313;

        forAllSystems = lib.genAttrs lib.systems.flakeExposed;

        workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};

        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        editableOverlay = workspace.mkEditablePyprojectOverlay {
          root = "$REPO_ROOT";
        };

        pythonSets = forAllSystems (
          system:
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
            (
              lib.composeManyExtensions [
                pyproject-build-systems.overlays.wheel
                overlay
              ]
            )
        );

        projectNameInToml = "bar-sika";
        thisProjectAsNixPkg = pythonSets.${system}.${projectNameInToml};

        appPythonEnv = pythonSets.${system}.mkVirtualEnv "${thisProjectAsNixPkg.pname}-env" workspace.deps.default;
      in {
        devShells = let
          pythonSet = pythonSets.${system}.overrideScope editableOverlay;
          virtualenv = pythonSet.mkVirtualEnv "bar-sika-dev-env" workspace.deps.default;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              virtualenv
              pkgs.uv

              alsa-lib
              alsa-lib.dev
              alsa-utils
            ];
            env = {
              UV_NO_SYNC = "1";
              UV_PYTHON = pythonSet.python.interpreter;
              UV_PYTHON_DOWNLOADS = "never";
            };
            shellHook = ''
              unset PYTHONPATH
              export REPO_ROOT=$(git rev-parse --show-toplevel)
            '';
          };
        };

        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = thisProjectAsNixPkg.pname;
            version = thisProjectAsNixPkg.version;

            src = ./.;

            nativeBuildInputs = [
              pkgs.makeWrapper
            ];
            buildInputs = [
              appPythonEnv
              pkgs.alsa-lib.dev
              pkgs.alsa-utils
            ];

            installPhase = ''
              mkdir -p $out/share/${thisProjectAsNixPkg.pname}
              mkdir -p $out/bin

              # Copy templates and audio files
              cp -r templates $out/share/${thisProjectAsNixPkg.pname}/
              cp -r src/bar_sika/static $out/share/${thisProjectAsNixPkg.pname}/
              mkdir -p $out/share/${thisProjectAsNixPkg.pname}/audio
              cp audio/exports/*.wav $out/share/${thisProjectAsNixPkg.pname}/audio/

              # Create wrapper script
              makeWrapper ${appPythonEnv}/bin/bar-sika $out/bin/${thisProjectAsNixPkg.pname} \
                --chdir $out/share/${thisProjectAsNixPkg.pname} \
                 --set BAR_SIKA_DATA_DIR $out/share/${thisProjectAsNixPkg.pname} \
                --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [pkgs.alsa-lib]}
            '';

            meta = with pkgs.lib; {
              description = "Bar Sika audio application";
              license = licenses.mit;
            };
          };
          ${thisProjectAsNixPkg.pname} = self.packages.${system}.default;
        };

        apps = {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/${thisProjectAsNixPkg.pname}";
          };
          ${thisProjectAsNixPkg.pname} = self.apps.${system}.default;
        };
      }
    );
}

# bar-sika

bar-sika is a python application that drives the siren sound effects for a bar table I built for my fire station. It is designed to run on a Raspberry Pi and uses GPIO pins to get input.

## Usage

### Standard Linux Systems

#### Requirements

- Python 3.11 or higher
- `uv` package manager
- GPIO access (typically requires running as root or being in the `gpio` group)
- systemd (for service management)

#### Installation Steps

1. Clone the repository:

```bash
git clone https://github.com/cyrilschreiber3/bar-sika.git
cd bar-sika
```

2. Install dependencies using uv:

```bash
uv sync
```

3. Install the systemd service file:

```bash
sudo cp bar-sika.service /etc/systemd/system/
sudo systemctl daemon-reload
```

4. Enable and start the service:

```bash
sudo systemctl enable bar-sika
sudo systemctl start bar-sika
```

### NixOS

1. Import the flake into your system configuration:

```nix
# flake.nix
{
  inputs.bar-sika = {
    url = "github:cyrilschreiber3/bar-sika";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, bar-sika }: {
    nixosConfigurations.myHost = nixpkgs.lib.nixosSystem {
      modules = [
        # Your NixOS modules here
      ];
    };
  };
}
```

2. Import the NixOS module and enable the service:

```nix
# configuration.nix
{
    imports = [
        bar-sika.nixosModules.default
    ];

    nixpkgs.overlays = [
        bar-sika.overlays.default
    ];

    services.bar-sika = {
        enable = true;
    };
}
```

3. Rebuild your system:

```bash
sudo nixos-rebuild switch
```

## Development

Build, copy to Raspberry Pi, and get the executable path:

```bash
nix build .#packages.aarch64-linux.default && nix copy --to ssh://<user>@<raspberry_pi_ip> .#packages.aarch64-linux.default && ls -l result
```

This command will:

1. Build the package for ARM64 architecture
2. Copy the build result to the Raspberry Pi at `<user>@<raspberry_pi_ip>`
3. Display the nix store path via the `result` symlink

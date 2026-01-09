{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.bar-sika;
in {
  options.services.bar-sika = {
    enable = mkEnableOption "Bar Sika audio application";
    enablePigpiodService = mkEnableOption "Enable pigpiod service for GPIO control";

    package = mkOption {
      type = types.package;
      default = pkgs.bar-sika;
      defaultText = literalExpression "pkgs.bar-sika";
      description = "The bar-sika package to use.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.bar-sika = {
      description = "Bar Sika audio application";
      after = ["network.target" "pigpiod.service"];
      wantedBy = ["multi-user.target"];
      wants = mkIf cfg.enablePigpiodService ["pigpiod.service"];

      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStartPre = [
          "${pkgs.alsa-utils}/bin/amixer sset Headphone 100%"
        ];
        ExecStart = "${cfg.package}/bin/bar-sika";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    systemd.services.pigpiod = mkIf cfg.enablePigpiodService {
      description = "Pigpio Daemon";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStart = "${pkgs.pigpio}/bin/pigpiod -g";
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStopSec = "5s";
      };
    };
  };
}

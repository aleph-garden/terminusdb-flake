{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.terminusdb;
  optionsLib = import ../../lib/options.nix { inherit lib pkgs; };
in
{
  options.services.terminusdb = optionsLib.mkTerminusDBOptions { isSystem = false; } // {
    dataDir = mkOption {
      type = types.path;
      default = "${config.home.homeDirectory}/.local/share/terminusdb";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/.local/share/terminusdb"'';
      description = lib.mdDoc "Directory where TerminusDB stores its data";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.terminusdb = {
      Unit = {
        Description = "TerminusDB Graph Database Server (User)";
        After = [ "network.target" ];
      };

      Service = {
        Type = "simple";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/terminusdb serve";
        Restart = "on-failure";
        RestartSec = "5s";

        Environment = [
          "TERMINUSDB_SERVER_DB_PATH=${cfg.dataDir}"
          "TERMINUSDB_SERVER_PORT=${toString cfg.port}"
          "TERMINUSDB_SERVER_IP=${cfg.address}"
        ] ++ (mapAttrsToList (k: v: "${k}=${v}") cfg.extraConfig);
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Ensure data directory exists
    home.activation.terminusdbInit = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -d "${cfg.dataDir}" ]; then
        $DRY_RUN_CMD mkdir -p "${cfg.dataDir}"
      fi

      if [ ! -d "${cfg.dataDir}/db" ]; then
        $DRY_RUN_CMD ${cfg.package}/bin/terminusdb store init
      fi
    '';
  };
}

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.terminusdb;
  optionsLib = import ../../lib/options.nix { inherit lib pkgs; };
in
{
  options.services.terminusdb = optionsLib.mkTerminusDBOptions { isSystem = true; } // {
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Open firewall port for TerminusDB";
    };
  };

  config = mkIf cfg.enable {
    users.users.terminusdb = {
      isSystemUser = true;
      group = "terminusdb";
      description = "TerminusDB system user";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.terminusdb = { };

    systemd.services.terminusdb = {
      description = "TerminusDB Graph Database Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        TERMINUSDB_SERVER_DB_PATH = cfg.dataDir;
        TERMINUSDB_SERVER_PORT = toString cfg.port;
        TERMINUSDB_SERVER_IP = cfg.address;
      } // cfg.extraConfig;

      serviceConfig = {
        Type = "simple";
        User = "terminusdb";
        Group = "terminusdb";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/terminusdb serve";
        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      preStart = ''
        # Initialize database if dataDir is empty
        if [ ! -d "${cfg.dataDir}/db" ]; then
          echo "Initializing TerminusDB database..."
          # TerminusDB requires TERMINUSDB_SERVER_DB_PATH and working directory
          cd ${cfg.dataDir}
          env TERMINUSDB_SERVER_DB_PATH=${cfg.dataDir} ${cfg.package}/bin/terminusdb store init
        fi
      '';
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

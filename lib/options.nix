{ lib, pkgs, ... }:

with lib;

{
  mkTerminusDBOptions = { isSystem ? true }: {
    enable = mkEnableOption (lib.mdDoc "TerminusDB database server");

    package = mkOption {
      type = types.package;
      default = pkgs.terminusdb;
      defaultText = literalExpression "pkgs.terminusdb";
      description = lib.mdDoc "The TerminusDB package to use";
    };

    dataDir = mkOption {
      type = types.path;
      # Only provide default for system use; home-manager module will override
      default = "/var/lib/terminusdb";
      defaultText = literalExpression ''
        if isSystem then "/var/lib/terminusdb"
        else "\''${config.home.homeDirectory}/.local/share/terminusdb"
      '';
      description = lib.mdDoc "Directory where TerminusDB stores its data";
    };

    port = mkOption {
      type = types.port;
      default = 6363;
      description = lib.mdDoc "Port for TerminusDB HTTP server";
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = lib.mdDoc "Address to bind TerminusDB server";
    };

    extraConfig = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = literalExpression ''
        {
          TERMINUSDB_SERVER_NAME = "my-server";
          TERMINUSDB_LOG_LEVEL = "debug";
        }
      '';
      description = lib.mdDoc "Extra environment variables for TerminusDB";
    };
  };
}

{ lib, pkgs, ... }:

with lib;

{
  mkTerminusDBOptions = { isSystem ? true }: {
    enable = mkEnableOption "TerminusDB database server";

    package = mkOption {
      type = types.package;
      default = pkgs.terminusdb;
      defaultText = literalExpression "pkgs.terminusdb";
      description = "The TerminusDB package to use";
    };

    dataDir = mkOption {
      type = types.path;
      default = if isSystem then "/var/lib/terminusdb" else "\${config.home.homeDirectory}/.local/share/terminusdb";
      description = "Directory where TerminusDB stores its data";
    };

    port = mkOption {
      type = types.port;
      default = 6363;
      description = "Port for TerminusDB HTTP server";
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to bind TerminusDB server";
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
      description = "Extra environment variables for TerminusDB";
    };
  };
}

{ config, pkgs, ... }:

{
  # Add the TerminusDB flake to your inputs, then:
  services.terminusdb = {
    enable = true;
    port = 6363;
    address = "127.0.0.1";
    dataDir = "${config.home.homeDirectory}/.local/share/terminusdb";

    extraConfig = {
      TERMINUSDB_SERVER_NAME = "my-personal-db";
    };
  };
}

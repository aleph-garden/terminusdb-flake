{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.terminusdb.nixosModules.default
  ];

  services.terminusdb = {
    enable = true;
    port = 6363;
    address = "127.0.0.1";
    openFirewall = false; # Set to true to allow external access
    dataDir = "/var/lib/terminusdb";

    extraConfig = {
      TERMINUSDB_SERVER_NAME = "my-terminusdb";
      # TERMINUSDB_ADMIN_PASS = "admin"; # Set admin password
    };
  };
}

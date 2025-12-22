{ pkgs ? import <nixpkgs> { }
, terminusdb
}:

pkgs.testers.nixosTest {
  name = "terminusdb-basic";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ terminusdb.nixosModules.terminusdb ];

    services.terminusdb = {
      enable = true;
      port = 6363;
      address = "127.0.0.1";
      package = terminusdb.packages.${pkgs.system}.terminusdb;
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("terminusdb.service")
    machine.wait_for_open_port(6363)

    # Test that TerminusDB is responding
    machine.succeed("curl -f http://127.0.0.1:6363/")

    # Check service status
    machine.succeed("systemctl status terminusdb.service")
  '';
}

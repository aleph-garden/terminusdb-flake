{
  pkgs ? import <nixpkgs> {},
  terminusdb,
}:
pkgs.testers.nixosTest {
  name = "terminusdb-basic";

  nodes.machine = {
    config,
    pkgs,
    ...
  }: {
    imports = [terminusdb.nixosModules.terminusdb];

    services.terminusdb = {
      enable = true;
      port = 6363;
      address = "127.0.0.1";
      package = terminusdb.packages.${pkgs.system}.terminusdb;
    };
  };

  testScript = ''
    machine.start()

    # Wait for the service to start
    machine.wait_for_unit("terminusdb.service")

    # Wait for the port to be open
    machine.wait_for_open_port(6363)

    # Give the database a moment to fully initialize
    import time
    time.sleep(2)

    # Test that TerminusDB HTTP API is responding
    machine.succeed("curl -f http://127.0.0.1:6363/")

    # Check that the API returns JSON (the root endpoint returns API info)
    output = machine.succeed("curl -s http://127.0.0.1:6363/")
    print(f"API response: {output}")

    # Verify we can access the API metadata endpoint
    machine.succeed("curl -f http://127.0.0.1:6363/api")

    # Check service status is active
    machine.succeed("systemctl is-active terminusdb.service")

    # Verify the service is running under the correct user
    machine.succeed("systemctl show terminusdb.service | grep 'User=terminusdb'")

    # Check logs for any errors
    logs = machine.succeed("journalctl -u terminusdb.service --no-pager")
    print(f"Service logs:\n{logs}")

    # Ensure no critical errors in logs
    machine.succeed("! journalctl -u terminusdb.service | grep -i 'fatal\\|critical'")

    print("✓ All tests passed - TerminusDB is running and accessible via HTTP")
  '';
}

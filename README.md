# TerminusDB Nix Flake

A Nix flake providing TerminusDB packages and NixOS/home-manager modules.

## Quick Start

### NixOS

```nix
{
  inputs.terminusdb.url = "github:aleph-garden/terminusdb-flake";

  # In your configuration:
  services.terminusdb = {
    enable = true;
    port = 6363;
    dataDir = "/var/lib/terminusdb";
  };
}
```

### Home Manager

```nix
{
  imports = [ inputs.terminusdb.homeManagerModules.default ];

  services.terminusdb = {
    enable = true;
    dataDir = "${config.home.homeDirectory}/.local/share/terminusdb";
  };
}
```

### Direct Usage

```bash
nix run github:aleph-garden/terminusdb-flake
```

## Dashboard (Optional)

The web dashboard is deprecated. To enable it:

```nix
services.terminusdb.package = pkgs.terminusdb.override { withDashboard = true; };
```

## Configuration

- `enable`: Enable the service (default: false)
- `port`: HTTP port (default: 6363)
- `address`: Bind address (default: "127.0.0.1")
- `dataDir`: Data directory
- `extraConfig`: Environment variables
- `openFirewall`: Open firewall (NixOS only, default: false)

## Examples

See `examples/` directory for complete configurations.

## Links

- [TerminusDB](https://terminusdb.com/)
- [Documentation](https://terminusdb.com/docs)

## License

MIT License. TerminusDB is Apache 2.0.

> [!NOTE]
> This flake was developed with assistance from an AI assistant (Claude Code)

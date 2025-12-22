# TerminusDB Nix Flake

A Nix flake providing TerminusDB packages and NixOS/home-manager modules for easy deployment and development.

## Features

- **Package**: Pre-built TerminusDB server and command-line tools
- **NixOS Module**: System-level service with security hardening
- **Home Manager Module**: User-level service for personal use
- **Development Shell**: Nix development environment with TerminusDB tools

## Quick Start

### Using as a Flake Input

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    terminusdb.url = "github:yourusername/terminusdb-flake";
  };

  outputs = { self, nixpkgs, terminusdb, ... }: {
    # Your configuration here
  };
}
```

### NixOS Configuration

Add the module to your NixOS configuration:

```nix
{ config, pkgs, ... }:

{
  imports = [
    terminusdb.nixosModules.default
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
```

After rebuilding your system, TerminusDB will be available at `http://127.0.0.1:6363`.

### Home Manager Configuration

Add the module to your home-manager configuration:

```nix
{ config, pkgs, ... }:

{
  imports = [
    terminusdb.homeManagerModules.default
  ];

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
```

After switching to the new configuration, start the service:

```bash
systemctl --user start terminusdb
```

### Direct Package Usage

Use TerminusDB directly without the service:

```bash
# Run TerminusDB in a Nix shell
nix run github:yourusername/terminusdb-flake

# Install to your profile
nix profile install github:yourusername/terminusdb-flake
```

## Configuration Options

### Common Options (NixOS and Home Manager)

- `enable` (boolean, default: `false`): Enable the TerminusDB service
- `package` (package, default: `pkgs.terminusdb`): The TerminusDB package to use
- `port` (port, default: `6363`): Port for the TerminusDB HTTP server
- `address` (string, default: `"127.0.0.1"`): Address to bind the server
- `dataDir` (path): Directory where TerminusDB stores its data
  - NixOS default: `/var/lib/terminusdb`
  - Home Manager default: `~/.local/share/terminusdb`
- `extraConfig` (attribute set, default: `{}`): Extra environment variables for TerminusDB

### NixOS-Only Options

- `openFirewall` (boolean, default: `false`): Open firewall port for TerminusDB

### Environment Variables

Common environment variables you can set via `extraConfig`:

- `TERMINUSDB_SERVER_NAME`: Server name for the instance
- `TERMINUSDB_ADMIN_PASS`: Admin password (use with caution)
- `TERMINUSDB_LOG_LEVEL`: Log level (debug, info, warning, error)
- `TERMINUSDB_AUTOLOGIN_ENABLED`: Enable auto-login (true/false)

See the [TerminusDB documentation](https://terminusdb.com/docs) for more environment variables.

## Examples

See the `examples/` directory for complete configuration examples:

- `examples/nixos-configuration.nix`: NixOS system-level service
- `examples/home-manager-configuration.nix`: Home Manager user-level service

## Development

To develop or test this flake:

```bash
# Clone the repository
git clone https://github.com/yourusername/terminusdb-flake.git
cd terminusdb-flake

# Enter the development shell
nix develop

# Build the package
nix build

# Run TerminusDB
nix run
```

### Project Structure

```
.
├── flake.nix                 # Main flake configuration
├── packages/
│   └── terminusdb/          # TerminusDB package definition
├── modules/
│   ├── nixos/               # NixOS module
│   └── home-manager/        # Home Manager module
├── lib/
│   └── options.nix          # Shared module options
└── examples/                # Example configurations
```

## Security Considerations

### NixOS Module

The NixOS module includes security hardening:

- Runs as a dedicated `terminusdb` system user
- Private `/tmp` directory
- Protected system and home directories
- No new privileges
- Private devices
- Protected kernel tunables and modules

### Network Access

By default, TerminusDB binds to `127.0.0.1` (localhost only). To allow external access:

1. Set `address = "0.0.0.0";` to bind to all interfaces
2. For NixOS: Set `openFirewall = true;` to open the firewall port
3. Consider using a reverse proxy (nginx, caddy) with SSL/TLS

## Troubleshooting

### Service won't start

Check the service logs:

```bash
# NixOS
journalctl -u terminusdb -f

# Home Manager
journalctl --user -u terminusdb -f
```

### Data directory issues

Ensure the data directory has the correct permissions:

```bash
# NixOS (as root)
chown -R terminusdb:terminusdb /var/lib/terminusdb

# Home Manager
chmod 755 ~/.local/share/terminusdb
```

### Port already in use

If port 6363 is already in use, change it in the configuration:

```nix
services.terminusdb.port = 6364;
```

## License

This Nix flake is provided under the MIT License. TerminusDB itself is licensed under Apache 2.0.

## Contributing

Contributions are welcome! Please open issues or pull requests on GitHub.

## Links

- [TerminusDB Official Site](https://terminusdb.com/)
- [TerminusDB Documentation](https://terminusdb.com/docs)
- [TerminusDB GitHub](https://github.com/terminusdb/terminusdb)
- [Nix Flakes Documentation](https://nixos.wiki/wiki/Flakes)

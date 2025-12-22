# TerminusDB Build Requirements Research

**Date:** 2025-12-22
**Repository:** https://github.com/terminusdb/terminusdb
**Latest Version:** 12.0.2 (released 2025-12-16)

## Overview

TerminusDB is a graph database implemented primarily in Prolog (70.8%) with a Rust storage backend (8.8%) introduced in version 11. The project also includes JavaScript components (18.5%) for testing and client interfaces.

## Build Dependencies

### Core Tools
- **SWI-Prolog** - Primary runtime and compilation system
  - Version: Not explicitly specified in Makefile
  - Used for: Main application logic, compilation to standalone binary

- **Rust** - Storage backend implementation
  - Edition: Not specified (Cargo.toml not found in root)
  - Component: `libterminusdb_dylib` (dynamic library)
  - Tools: `cargo` for building Rust components

- **Make** - Build orchestration
  - Delegates to `distribution/Makefile.prolog` and `distribution/Makefile.rust`

### Additional Tools
- **Git** - For commit hash retrieval during build
- **Node.js/npm** - JavaScript testing (Mocha framework)
- **ronn** - Man page generation
- **envsubst** - Environment variable substitution in templates

### Prolog Packs (Dependencies)
- **tus pack** - Installed via `make install-tus`
- **jwt_io pack** - Installed via `make install-jwt`

## Build Process

### Development Build
```bash
make dev
./terminusdb test
```

Creates an unstripped binary suitable for development and debugging.

### Production Build
```bash
make
```

Generates a standalone executable with:
- Library stripping for smaller binary size
- Optimization flags (`-O`)
- Strict error/warning handling (`--on-error=halt --on-warning=halt`)
- Clean exit after main (`-t 'main, halt'`)

### Build Steps (Internal)
1. Execute default target → delegates to `distribution/Makefile.prolog`
2. Build Rust storage backend via `distribution/Makefile.rust`
3. Compile Prolog code and dependencies
4. Link Rust dylib with Prolog runtime
5. Create standalone binary using SWI-Prolog's compilation system
6. Generate documentation from templates

## Runtime Dependencies

### Required Environment Variables
- `TERMINUSDB_ADMIN_PASS` - Administrator password (mandatory)

### Optional Configuration
- `TERMINUSDB_SERVER_NAME` - Server identifier
- `TERMINUSDB_LOG_LEVEL` - Logging verbosity
- `TERMINUSDB_SERVER_PORT` - HTTP port (default: 6363)
- `TERMINUSDB_SERVER_IP` - Bind address (default: 127.0.0.1)
- `TERMINUSDB_SERVER_DB_PATH` - Database storage directory

## Testing

### Unit Tests (Prolog)
```bash
make test
```

### Integration Tests (JavaScript/Node)
```bash
make test-int
```
Uses Mocha test framework.

### Linting
```bash
make download-lint  # First time only
make lint          # Prolog linting
make lint-mocha    # JavaScript linting
```

### Complete CI Workflow
```bash
make clean dev restart lint lint-mocha test test-int
```

## Installation Methods

### 1. Docker (Official/Recommended)
```bash
# Create .env with TERMINUSDB_ADMIN_PASS
docker compose up
# Access at localhost:6363
```

### 2. Snap Package
Command-line client for push/pull operations (ML/Ops workflows).

### 3. From Source
See official documentation at terminusdb.org/docs

## Directory Structure

- `/src/` - Prolog source code
  - `/src/core/` - Core database logic
  - `/src/interactive.pl` - Interactive mode entry point
- `/distribution/` - Build system
  - `Makefile.prolog` - Prolog build rules
  - `Makefile.rust` - Rust build rules
- `/tests/` - Test suites
  - Shell scripts for server management
  - JavaScript/Mocha integration tests
- Root contains main `Makefile` and Docker configuration

## Platform Support

- **Linux** - Primary platform (Docker, source build)
- **macOS** - Supported (development build target exists)
- **Windows** - Via Docker (setup guide available from DFRNT)

## Known Issues & Considerations

### For Nix Packaging

1. **Rust Component** - Must build `libterminusdb_dylib` separately
2. **SWI-Prolog Version** - No explicit minimum version; may need testing
3. **Prolog Packs** - `tus` and `jwt_io` must be available or bundled
4. **Node.js** - Only needed for testing, not runtime
5. **Standalone Binary** - SWI-Prolog can create self-contained executable
6. **Data Directory** - Needs writable storage path at runtime

### Build Strategy for Nix

- Build Rust dylib first using `rustPlatform.buildRustPackage`
- Use `swiProlog` from nixpkgs as build input
- Install required Prolog packs during build phase
- Create standalone binary via SWI-Prolog compilation
- Wrap final binary with data directory configuration

## Documentation Links

- Main documentation: https://terminusdb.org/docs
- GitHub repository: https://github.com/terminusdb/terminusdb
- REST API, GraphQL, WOQL query language docs available at terminusdb.org

## Version History Notes

- **Version 11+**: Introduced Rust storage backend for performance
- **Version 12.0.2**: Latest stable (as of 2025-12-16)
- Multi-modal API: REST, GraphQL, WOQL query language

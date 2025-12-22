{ lib
, stdenv
, fetchFromGitHub
, swi-prolog
, rustPlatform
, openssl
, pkg-config
, git
, makeWrapper
, m4
, gmp
, protobuf
, libclang
, llvmPackages
, libjwt
}:

stdenv.mkDerivation rec {
  pname = "terminusdb";
  version = "12.0.2";

  src = fetchFromGitHub {
    owner = "terminusdb";
    repo = "terminusdb";
    rev = "v${version}";
    hash = "sha256-j60mZ+coA0SL+BQsNp12aIyLkdIE7oxLzKNy7Nq0Las=";
  };

  # SWI-Prolog pack dependencies
  tusPack = fetchFromGitHub {
    owner = "terminusdb";
    repo = "tus";
    rev = "v0.0.16";
    hash = "sha256-NQGvDFtGEXhSXIZ7dZ2r13q8hRpYXkA9/NlFKED1ANM=";
  };

  jwtPack = fetchFromGitHub {
    owner = "terminusdb-labs";
    repo = "jwt_io";
    rev = "v1.0.4";
    hash = "sha256-YywD0zg4ft075AaxgNDOuxVxQSsQjP0BXTW5YLl2TS0=";
  };

  # Build the Rust storage backend separately
  rustBackend = rustPlatform.buildRustPackage {
    pname = "terminusdb-rust-backend";
    inherit version src;

    sourceRoot = "${src.name}/src/rust";

    cargoHash = "sha256-zF506S4SiWx/uYyN2Trm4XPVUIU2K/qoNSjfKthLVuw=";

    nativeBuildInputs = [ pkg-config m4 protobuf swi-prolog ];
    buildInputs = [ openssl gmp ];

    # Bindgen needs libclang and system headers
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-I${stdenv.cc.libc.dev}/include";

    # Help the linker find SWI-Prolog library
    preConfigure = ''
      export NIX_LDFLAGS="-L${swi-prolog}/lib $NIX_LDFLAGS"
    '';

    # Don't run tests during build (may require additional setup)
    doCheck = false;

    postInstall = ''
      # Copy the dynamic library to the output
      mkdir -p $out/lib
      if [ -f target/release/libterminusdb_dylib.so ]; then
        cp target/release/libterminusdb_dylib.so $out/lib/
      elif [ -f target/release/libterminusdb_dylib.dylib ]; then
        cp target/release/libterminusdb_dylib.dylib $out/lib/
      fi
    '';
  };

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    git
  ];

  buildInputs = [
    swi-prolog
    openssl
    libjwt
  ];

  # Prevent network access during build
  __noChroot = false;

  # Don't strip the binary - it contains embedded Prolog state
  dontStrip = true;

  # Patch the Makefile to skip Rust build (we built it separately)
  postPatch = ''
    # Replace the Rust build rule with a no-op
    substituteInPlace distribution/Makefile.prolog \
      --replace-fail $'$(RUST_TARGET):\n\t@$(MAKE) -f distribution/Makefile.rust $@' \
                     $'$(RUST_TARGET):\n\t@echo "Using pre-built Rust library from Nix"'

    # Add -p foreign flag to tell SWI-Prolog where to find librust
    # Remove --quiet to see build output
    substituteInPlace distribution/Makefile.prolog \
      --replace-fail '-f src/bootstrap.pl' '-p foreign=src/rust -f src/bootstrap.pl' \
      --replace-fail '--quiet' ""

    # Patch load_paths.pl to NOT set dashboard path at load time
    # Instead, it will be set at runtime via environment variable
    # This prevents the build-time path from being baked into the saved state
    substituteInPlace src/load_paths.pl \
      --replace-fail ':- add_dashboard_path.' \
                     '% Dashboard path set via TERMINUSDB_DASHBOARD_PATH at runtime'

    # Patch cli_toplevel to set dashboard path at runtime
    # Add the call right after getting argv
    sed -i '/current_prolog_flag(argv, Argv),/a\    (load_paths:add_dashboard_path -> true ; true),' \
      src/cli/main.pl
  '';

  preBuild = ''
    # Link the Rust backend library where the Makefile expects it
    mkdir -p src/rust
    if [ -f ${rustBackend}/lib/libterminusdb_dylib.so ]; then
      ln -s ${rustBackend}/lib/libterminusdb_dylib.so src/rust/librust.so
      touch -h src/rust/librust.so
    elif [ -f ${rustBackend}/lib/libterminusdb_dylib.dylib ]; then
      ln -s ${rustBackend}/lib/libterminusdb_dylib.dylib src/rust/librust.dylib
      touch -h src/rust/librust.dylib
    else
      echo "ERROR: No Rust backend library found!"
      ls -la ${rustBackend}/lib/ || echo "Backend lib directory doesn't exist"
      exit 1
    fi
  '';

  buildPhase = ''
    runHook preBuild

    # Set HOME to a writable directory for SWI-Prolog pack installation
    export HOME=$PWD/.home
    mkdir -p $HOME

    # Install required Prolog packs from pre-fetched sources
    mkdir -p .deps
    cp -r ${tusPack} .deps/tus
    cp -r ${jwtPack} .deps/jwt_io
    chmod -R +w .deps

    # Create pack directory
    mkdir -p $HOME/.local/share/swi-prolog/pack

    # Install packs using SWI-Prolog's pack_install (non-interactive, skip tests)
    ${swi-prolog}/bin/swipl --on-error=halt --on-warning=halt -g "pack_remove(tus, [silent(true)]), pack_install('file://$PWD/.deps/tus', [upgrade(true), silent(true), interactive(false), test(false)]), pack_info(tus), halt."
    ${swi-prolog}/bin/swipl --on-error=halt --on-warning=halt -g "pack_remove(jwt_io, [silent(true)]), pack_install('file://$PWD/.deps/jwt_io', [upgrade(true), silent(true), interactive(false), test(false)]), pack_info(jwt_io), halt."

    # Build the standalone binary using the production target
    # This uses distribution/Makefile.prolog with our patches
    # The -p foreign=src/rust flag tells SWI-Prolog where to find librust
    make

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/dashboard/assets

    # Install the standalone binary
    if [ -f terminusdb ]; then
      install -m755 terminusdb $out/bin/.terminusdb-unwrapped
    else
      echo "Error: terminusdb binary not found after build"
      exit 1
    fi

    # Install dashboard files (web UI) at $out/dashboard
    # This matches the path structure that top_level_directory expects
    install -m644 dashboard/src/index.html $out/dashboard/
    install -m644 dashboard/src/output.css $out/dashboard/assets/

    # Create a wrapper script that properly invokes the Prolog saved state
    # The saved state is embedded in the binary, but we need to invoke it with
    # the correct arguments to run cli_toplevel with command-line args
    cat > $out/bin/terminusdb << EOF
#!${stdenv.shell}
# TerminusDB launcher script
# This wrapper ensures the saved Prolog state runs cli_toplevel with args

# Get the directory where this script is located
DIR="\$(cd "\$(dirname "\$0")" && pwd)"

# Set default environment variables
export TERMINUSDB_SERVER_NAME="terminusdb-nix"
export TERMINUSDB_SERVER_PORT="6363"
export TERMINUSDB_SERVER_IP="127.0.0.1"
export PATH="${lib.makeBinPath [ git ]}:\$PATH"

# Set absolute path to dashboard - this gets read by load_paths.pl at runtime
export TERMINUSDB_DASHBOARD_PATH="$out/dashboard"

# Run the TerminusDB binary with arguments passed after --
# This ensures arguments go to cli_toplevel via the argv flag
exec "\$DIR/.terminusdb-unwrapped" -- "\$@"
EOF

    chmod +x $out/bin/terminusdb

    runHook postInstall
  '';

  meta = with lib; {
    description = "TerminusDB graph database server with document interface";
    longDescription = ''
      TerminusDB is an open-source graph database with a document interface.
      It uses a distributed collaboration model and supports ACID transactions,
      schema enforcement, and rich querying capabilities via WOQL, GraphQL, and REST APIs.

      Built with SWI-Prolog and a Rust storage backend for performance.
    '';
    homepage = "https://terminusdb.com";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.unix;
    mainProgram = "terminusdb";
  };
}

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
  '';

  preBuild = ''
    echo "=== PREBULD HOOK STARTING ==="

    # Link the Rust backend library where the Makefile expects it
    mkdir -p src/rust
    if [ -f ${rustBackend}/lib/libterminusdb_dylib.so ]; then
      ln -s ${rustBackend}/lib/libterminusdb_dylib.so src/rust/librust.so
      # Touch it to ensure make sees it as up-to-date
      touch -h src/rust/librust.so
      echo "DEBUG: Created symlink src/rust/librust.so -> ${rustBackend}/lib/libterminusdb_dylib.so"
      ls -la src/rust/
    elif [ -f ${rustBackend}/lib/libterminusdb_dylib.dylib ]; then
      ln -s ${rustBackend}/lib/libterminusdb_dylib.dylib src/rust/librust.dylib
      touch -h src/rust/librust.dylib
      echo "DEBUG: Created symlink src/rust/librust.dylib -> ${rustBackend}/lib/libterminusdb_dylib.dylib"
      ls -la src/rust/
    else
      echo "ERROR: No Rust backend library found!"
      ls -la ${rustBackend}/lib/ || echo "Backend lib directory doesn't exist"
    fi
  '';

  buildPhase = ''
    runHook preBuild

    echo "=== BUILD PHASE STARTING (rebuild to see output) ==="

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
    echo "=== Building TerminusDB standalone binary (verbose mode) ==="
    echo "PWD: $PWD"
    echo "HOME: $HOME"
    make

    echo "=== Files created after build ==="
    ls -lh terminusdb* 2>/dev/null || echo "No terminusdb files found"
    file terminusdb 2>/dev/null || echo "terminusdb binary not found"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Install the standalone binary
    if [ -f terminusdb ]; then
      install -m755 terminusdb $out/bin/terminusdb
    else
      echo "Error: terminusdb binary not found after build"
      exit 1
    fi

    # Wrap the binary to set up runtime environment
    wrapProgram $out/bin/terminusdb \
      --prefix PATH : ${lib.makeBinPath [ git ]} \
      --set TERMINUSDB_SERVER_NAME "terminusdb-nix" \
      --set TERMINUSDB_SERVER_PORT "6363" \
      --set TERMINUSDB_SERVER_IP "127.0.0.1"

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

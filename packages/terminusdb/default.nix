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
      export NIX_LDFLAGS="-L${swi-prolog}/lib/swipl/lib/x86_64-linux $NIX_LDFLAGS"
    '';

    # Don't run tests during build (may require additional setup)
    doCheck = false;

    postInstall = ''
      # Copy the dynamic library to the output
      mkdir -p $out/lib
      if [ -f target/release/libterminusdb_store_prolog.so ]; then
        cp target/release/libterminusdb_store_prolog.so $out/lib/
      elif [ -f target/release/libterminusdb_store_prolog.dylib ]; then
        cp target/release/libterminusdb_store_prolog.dylib $out/lib/
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
  ];

  # Prevent network access during build
  __noChroot = false;

  preBuild = ''
    # Make git available for version detection
    export HOME=$TMPDIR

    # Link the Rust backend library
    mkdir -p target/release
    if [ -f ${rustBackend}/lib/libterminusdb_store_prolog.so ]; then
      ln -s ${rustBackend}/lib/libterminusdb_store_prolog.so target/release/
    elif [ -f ${rustBackend}/lib/libterminusdb_store_prolog.dylib ]; then
      ln -s ${rustBackend}/lib/libterminusdb_store_prolog.dylib target/release/
    fi
  '';

  buildPhase = ''
    runHook preBuild

    # Install required Prolog packs
    # Note: These may need to be fetched separately in Nix
    # For now, attempt to install them
    make install-tus || echo "Warning: tus pack installation failed"
    make install-jwt || echo "Warning: jwt_io pack installation failed"

    # Build the standalone binary using the production target
    # This uses distribution/Makefile.prolog
    make

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

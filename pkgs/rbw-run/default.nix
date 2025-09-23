{ lib
, buildGoModule
, fetchFromGitHub
, rbw
, makeWrapper
}:

buildGoModule rec {
  pname = "rbw-run";
  version = "0.1.0";

  # If you're building from a local directory, use this instead:
  # src = ./.;
  
  # For a GitHub repository, use this:
  # src = fetchFromGitHub {
  #   owner = "your-username";
  #   repo = "rbw-run";
  #   rev = "v${version}";
  #   hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  # };

  # For local development, use the current directory
  src = ./.;

  # Since this is a single-file Go program with no external dependencies,
  # we need to create a minimal go.mod
  vendorHash = null;

  # Build dependencies
  nativeBuildInputs = [ makeWrapper ];

  # Ensure rbw is available at runtime
  buildInputs = [ rbw ];

  # Create go.mod if it doesn't exist
  preBuild = ''
    if [ ! -f go.mod ]; then
      cat > go.mod << EOF
module rbw-run

go 1.21
EOF
    fi
  '';

  # Build with CGO disabled for static linking and no references
  env.CGO_ENABLED = "0";
  
  # Build flags to create a static binary and remove build references
  ldflags = [
    "-s" "-w"  # Strip debug info and symbol table
  ];

  # Use standard Go build phases instead of custom installPhase
  # This properly handles the Go build process and avoids references

  # Wrap the binary to ensure rbw is in PATH
  postInstall = ''
    wrapProgram $out/bin/rbw-run \
      --prefix PATH : ${lib.makeBinPath [ rbw ]}
  '';

  meta = with lib; {
    description = "Run commands with environment variables from rbw secrets";
    longDescription = ''
      rbw-run is a utility that retrieves secrets from rbw (Rust Bitwarden CLI)
      and runs commands with those secrets as environment variables.
      
      The executable name is used as the secret name in rbw. All fields in the
      secret (except "executable" and "custom-type") are set as environment
      variables for the command.
    '';
    homepage = "https://github.com/your-username/rbw-run";
    license = licenses.mit;
    maintainers = with maintainers; [ ]; # Add your maintainer info here
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "rbw-run";
  };
}

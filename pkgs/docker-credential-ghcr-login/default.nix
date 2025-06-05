{ lib
, buildGoModule
, fetchFromGitHub
, gh
, makeWrapper
}:

buildGoModule rec {
  pname = "docker-credential-ghcr-login";
  version = "ca8ce48f12b6a9cd92e795514db75a2d6d248186";

  src = fetchFromGitHub {
    owner = "bradschwartz";
    repo = "docker-credential-ghcr-login";
    rev = "ca8ce48f12b6a9cd92e795514db75a2d6d248186";
    hash = "sha256-4D/6KNsgXui5KmnH6dauaAR+9q3O+uae9zkl/FyQS9w="; # Replace with actual hash
  };

  vendorHash = "sha256-Gh4AwyyxgPfNQRCufWOCPQUdcyTuc8FGrcVFF81b0pU="; # Replace with actual hash

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ gh ];

  # Ensure the gh CLI is available at runtime
  postInstall = ''
    wrapProgram $out/bin/docker-credential-ghcr-login \
      --prefix PATH : ${lib.makeBinPath [ gh ]}
  '';

  # Set the correct binary name for Docker credential helpers
  postBuild = ''
    # Docker credential helpers must be named docker-credential-<name>
    if [ -f "$GOPATH/bin/docker-credential-ghcr-login" ]; then
      # Already correctly named
      :
    elif [ -f "$GOPATH/bin/ghcr-login" ]; then
      mv "$GOPATH/bin/ghcr-login" "$GOPATH/bin/docker-credential-ghcr-login"
    elif [ -f "$GOPATH/bin/main" ]; then
      mv "$GOPATH/bin/main" "$GOPATH/bin/docker-credential-ghcr-login"
    fi
  '';

  meta = with lib; {
    description = "Docker credential helper for GitHub Container Registry (GHCR)";
    longDescription = ''
      A Docker credential helper that automagically authenticates to GitHub Container Registry
      using GitHub CLI (gh) credentials. It manages Personal Access Tokens (PATs) for 
      individuals to authenticate to GitHub Container Registry and push images.
      
      The tool uses your GitHub username/password to create a personal access token,
      leveraging the gh utilities to ensure the PAT has write:packages access.
      It relies on the gh configuration files as the source of truth for username
      and token, providing them to the Docker daemon when requested.
    '';
    homepage = "https://github.com/bradschwartz/docker-credential-ghcr-login";
    license = licenses.mit; # Assuming MIT license, verify from repository
    maintainers = with maintainers; [ ]; # Add your name here
    platforms = platforms.unix;
    mainProgram = "docker-credential-ghcr-login";
  };
}

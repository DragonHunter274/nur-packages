{
  lib,
  python313Packages,
  fetchFromGitHub,
  kustomize,
  fluxcd,
  kubernetes-helm,
}:

python313Packages.buildPythonApplication {
  pname = "flux-local";
  version = "8.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "allenporter";
    repo = "flux-local";
    tag = "8.1.0";
    hash = "sha256-kTfGqvva39o5PQInpBiwjr4sNIf0I6YqloqWUXGhOLY=";
  };

  build-system = [ python313Packages.setuptools ];

  dependencies = with python313Packages; [
    gitpython
    pyyaml
    aiofiles
    mashumaro
    nest-asyncio
    oras
    pytest
    pytest-asyncio
    python-slugify
  ];

  makeWrapperArgs = [
    "--prefix PATH : ${
      lib.makeBinPath [
        kustomize
        fluxcd
        kubernetes-helm
      ]
    }"
  ];

  # Tests require a git repo and external tools
  doCheck = false;

  meta = {
    description = "Tools for managing a local flux gitops repository";
    homepage = "https://github.com/allenporter/flux_local";
    license = lib.licenses.asl20;
    mainProgram = "flux-local";
  };
}

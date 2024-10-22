{ pkgs, lib, ... }:
pkgs.stdenv.mkDerivation rec {
  pname = "openbeken-flasher";
  version = "1.3";

  src = pkgs.fetchFromGitHub {
    owner = "openshwprojects";
    repo = "BK7231GUIFlashTool";
    rev = "v${version}";
    sha256 = "sha256-FN2rVKqYzgbIoLlSnLSTegpoSu5U41mAmpw0erzF4dQ=";
  };

  buildInputs = [ pkgs.mono pkgs.makeWrapper ];

  buildPhase = ''
    xbuild /p:Configuration=Debug BK7231Flasher.sln
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp -r BK7231Flasher/bin/Debug/* $out/lib/
    
    mkdir -p $out/bin
    makeWrapper ${pkgs.mono}/bin/mono $out/bin/openbeken-flasher \
      --add-flags "$out/lib/BK7231Flasher.exe"
  '';

  meta = with lib; {
    description = "OpenBK7231 GUI Flash Tool for BK7231/BK7231N chips";
    homepage = "https://github.com/openshwprojects/BK7231GUIFlashTool";
    license = lib.licenses.gpl3;
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };
}


{ lib
, buildDotnetModule
, fetchFromGitHub
}:

buildDotnetModule rec {
  pname = "openbeken-flasher";
  version = "1.3";

  src = fetchFromGitHub {
    owner = "openshwprojects";
    repo = "BK7231GUIFlashTool";
    rev = "v${version}";
    sha256 = "sha256-FN2rVKqYzgbIoLlSnLSTegpoSu5U41mAmpw0erzF4dQ=";
  };

  projectFile = "BK7231Flasher.sln";
  executables = [ "beken-flasher" ];
  nugetDeps = [];

  meta = with lib; {
    description = "GUI Flash tool for BK7231 WiFi chips";
    homepage = "https://github.com/openshwprojects/BK7231GUIFlashTool";
    license = licenses.gpl3;
    maintainers = with maintainers; [  ];
    platforms = platforms.unix;
  };
}

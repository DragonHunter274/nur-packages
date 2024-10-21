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
    sha256 = ""; # Add hash after first attempt
  };

  projectFile = "BK7231Flasher.sln";
  executables = [ "beken-flasher" ];

  meta = with lib; {
    description = "GUI Flash tool for BK7231 WiFi chips";
    homepage = "https://github.com/openshwprojects/BK7231GUIFlashTool";
    license = licenses.gpl3; # Adjust if this isn't the correct license
    maintainers = with maintainers; [  ]; # Add your maintainer name here
    platforms = platforms.unix;
  };
}

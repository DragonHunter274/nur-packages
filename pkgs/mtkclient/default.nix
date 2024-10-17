{ lib, python3, python3Packages, keystone, ... }:

python3Packages.buildPythonPackage rec {
  pname = "mtkclient";
  version = "2.0.1.freeze";

  src = pkgs.fetchFromGitHub {
    owner = "bkerler";
    repo = "mtkclient";
    rev = "2.0.1.freeze";
    sha256 = "y2VCfjds1fN2G9MHYZveT3NQqYF7RO26gBykHY1O6o8=";
  };

  pyproject = true;

  buildInputs = [ keystone ];  # Specifies the 'keystone' package as a build dependency

  propagatedBuildInputs = with python3Packages; [
    capstone
    colorama
    flake8
    fusepy
    keystone-engine
    mock
    pycryptodome
    pycryptodomex
    pyserial
    pyside6
    pyusb
    setuptools
    shiboken6
    unicorn
  ];

  postPatch = ''
    sed -i "s#if __name__ == '__main__':#def main():#g" mtk.py mtk_gui.py
    sed -i "s#mtkclient.mtk_gui:main#mtk_gui:main#g" pyproject.toml
  '';

  postFixup = ''
    cp -r *.py $out/lib/python${python3.pythonVersion}/site-packages/
    cp -r mtkclient $out/lib/python${python3.pythonVersion}/site-packages/
  '';

  meta = with lib; {
    mainProgram = "mtk";
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "MTK reverse engineering and flash tool";
    homepage = "https://github.com/bkerler/mtkclient";
    license = with licenses; [ gpl3Only ];
  };
}


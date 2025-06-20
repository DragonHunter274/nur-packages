{ pkgs }:

pkgs.python3Packages.buildPythonApplication rec {
  pname = "arduino-ip-monitor";
  version = "1.0.0";
  format = "other";

  src = ./.;

  propagatedBuildInputs = with pkgs.python3Packages; [
    pyserial
    netifaces
  ];

  installPhase = ''
    mkdir -p $out/bin
    install -m755 ${src}/arduino_ip_monitor.py $out/bin/arduino-ip-monitor
  '';

  meta = with pkgs.lib; {
    description = "Monitor and send IP addresses to an Arduino over serial";
    homepage = "https://example.com";
    license = pkgs.lib.licenses.mit;
    maintainers = with pkgs.lib.maintainers; [ ];
  };
}

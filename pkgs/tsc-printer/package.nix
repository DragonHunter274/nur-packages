{ lib
, stdenv
, fetchurl
, unzip
, buildFHSEnv
, patchelf
, gtk2
, libusb1
, cups
, cairo
, glib
, pango
, atk
, gdk-pixbuf
}:

let
  tscdriver-unwrapped = stdenv.mkDerivation rec {
    pname = "tscdriver-unwrapped";
    version = "1.2.13";

    src = fetchurl {
      url = "https://fs.tscprinters.com/system/files/linux64_v${version}.zip";
      sha256 = "8661fa914b0b07b4c3f32ab9900397a4cb3503e1f1e35aa081e21e6f20c6a2dd";
    };

    nativeBuildInputs = [ unzip patchelf ];

    dontPatchELF = true;

    unpackPhase = ''
      unzip $src
      tar xf Linux64_v${version}/barcodedriver-${version}-x86_64.tar.gz
      sourceRoot="barcodedriver-${version}"
    '';

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -vdm755 $out/bin
      install -vm755 thermalprinterui          $out/bin/
      install -vm755 thermalprinterut          $out/bin/

      install -vdm755 $out/lib/cups/backend
      install -vm755 backend/brusb             $out/lib/cups/backend/
      install -vm755 backend/brsocket          $out/lib/cups/backend/

      install -vdm755 $out/lib/cups/filter
      install -vm755 rastertobarcodetspl       $out/lib/cups/filter/rastertobarcodetspl

      install -vdm755 $out/share/cups/model/tsc-ppds
      install -vm644 ppd/*.ppd                 $out/share/cups/model/tsc-ppds/

      install -vDm644 thermalprinterui.png \
        $out/share/icons/hicolor/128x128/apps/thermalprinterui.png

      install -vDm644 barcodeprintersetting.desktop \
        $out/share/applications/barcodeprintersetting.desktop

      sed -i \
        -e 's|Exec=.*|Exec=thermalprinterui|' \
        -e 's|Icon=.*|Icon=thermalprinterui.png|' \
        $out/share/applications/barcodeprintersetting.desktop

      # Patch interpreter to use FHS /lib64 so the binary uses the FHS glibc
      patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 \
        $out/bin/thermalprinterui \
        $out/bin/thermalprinterut \
        $out/lib/cups/backend/brusb \
        $out/lib/cups/backend/brsocket \
        $out/lib/cups/filter/rastertobarcodetspl

      runHook postInstall
    '';
  };

  fhsEnv = buildFHSEnv {
    name = "tscdriver-fhs";
    targetPkgs = pkgs: with pkgs; [
      gtk2
      libusb1
      cups
      cairo
      glib
      pango
      atk
      gdk-pixbuf
      # Add more as needed — check with: ldd <binary> | grep "not found"
    ];
    runScript = "";
  };

in

stdenv.mkDerivation {
  pname = "tscdriver";
  version = "1.2.13";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -vdm755 $out/bin

    for bin in thermalprinterui thermalprinterut; do
      cat > $out/bin/$bin << EOF
#!/bin/sh
exec ${fhsEnv}/bin/tscdriver-fhs ${tscdriver-unwrapped}/bin/$bin "\$@"
EOF
      chmod +x $out/bin/$bin
    done

    ln -s ${tscdriver-unwrapped}/share $out/share
    ln -s ${tscdriver-unwrapped}/lib   $out/lib

    runHook postInstall
  '';

  meta = with lib; {
    description = "Drivers for TSC Printers";
    homepage = "https://www.tscprinters.com";
#    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}

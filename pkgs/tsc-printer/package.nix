{
  lib,
  stdenv,
  fetchurl,
  unzip,
  buildFHSEnv,
  patchelf,
  autoPatchelfHook,
  gtk2,
  libusb1,
  cups,
  cairo,
  glib,
  pango,
  atk,
  gdk-pixbuf,
}:

let
  tscdriver-unwrapped = stdenv.mkDerivation rec {
    pname = "tscdriver-unwrapped";
    version = "1.2.13";

    src = fetchurl {
      url = "https://fs.tscprinters.com/system/files/linux64_v${version}.zip";
      sha256 = "8661fa914b0b07b4c3f32ab9900397a4cb3503e1f1e35aa081e21e6f20c6a2dd";
    };

    nativeBuildInputs = [
      unzip
      patchelf
      autoPatchelfHook
    ];

    # autoPatchelfHook will fix rpaths for filter/backends using these
    buildInputs = [
      cups
      gtk2
      libusb1
      cairo
      glib
      pango
      atk
      gdk-pixbuf
    ];

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

      runHook postInstall
    '';

    # autoPatchelfHook runs after installPhase and patches rpaths on all ELF
    # binaries to point at Nix store libs. After that we override the
    # interpreter on the UI binaries so they use the FHS glibc at runtime.
    postFixup = ''
        # UI binaries: FHS interpreter for glibc compat
        patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 \
          $out/bin/thermalprinterui \
          $out/bin/thermalprinterut

        # Filter: needs libcups via dlopen at hardcoded FHS paths
        # Wrap it so it runs inside the FHS env which provides /usr/lib/libcups.so.2
        mv $out/lib/cups/filter/rastertobarcodetspl \
           $out/lib/cups/filter/.rastertobarcodetspl-wrapped
        cat > $out/lib/cups/filter/rastertobarcodetspl << EOF
      #!/bin/sh
      exec ${fhsEnv}/bin/tscdriver-fhs \
        $out/lib/cups/filter/.rastertobarcodetspl-wrapped "\$@"
      EOF
        chmod +x $out/lib/cups/filter/rastertobarcodetspl

        # Same for backends
        for b in brusb brsocket; do
          mv $out/lib/cups/backend/$b \
             $out/lib/cups/backend/.$b-wrapped
          cat > $out/lib/cups/backend/$b << EOF
      #!/bin/sh
      exec ${fhsEnv}/bin/tscdriver-fhs \
        $out/lib/cups/backend/.$b-wrapped "\$@"
      EOF
          chmod +x $out/lib/cups/backend/$b
        done
    '';

  };

  fhsEnv = buildFHSEnv {
    name = "tscdriver-fhs";
    targetPkgs =
      pkgs: with pkgs; [
        gtk2
        libusb1
        cups
        cairo
        glib
        pango
        atk
        gdk-pixbuf
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

        # Expose filter and backends for CUPS — rpaths already fixed by
        # autoPatchelfHook so no FHS wrapper needed, CUPS can invoke directly
        ln -s ${tscdriver-unwrapped}/lib $out/lib
        ln -s ${tscdriver-unwrapped}/share $out/share

        runHook postInstall
  '';

  meta = with lib; {
    description = "Drivers for TSC Printers";
    homepage = "https://www.tscprinters.com";
    #   license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}

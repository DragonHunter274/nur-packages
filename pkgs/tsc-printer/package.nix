{
  lib,
  stdenv,
  pkgs,
  fex,  # native FEX interpreter for the build/host platform (unused on x86_64)
}:

let
  isNativeX86 = stdenv.hostPlatform.isx86_64;

  # The vendor binary is x86_64-only no matter what host we're on, so always
  # resolve its runtime deps from an explicit x86_64-linux package set.
  pkgsX86 = if isNativeX86 then pkgs else import pkgs.path { system = "x86_64-linux"; };

  fexInterpreter = "${fex}/bin/FEXInterpreter";
  execPrefix = lib.optionalString (!isNativeX86) "${fexInterpreter} ";

  version = "1.2.13";

  tscdriver-unwrapped = pkgsX86.stdenv.mkDerivation rec {
    pname = "tscdriver-unwrapped";
    inherit version;

    src = pkgsX86.fetchurl {
      url = "https://fs.tscprinters.com/system/files/linux64_v${version}.zip";
      sha256 = "8661fa914b0b07b4c3f32ab9900397a4cb3503e1f1e35aa081e21e6f20c6a2dd";
    };

    nativeBuildInputs = with pkgsX86; [ unzip patchelf autoPatchelfHook ];
    buildInputs = with pkgsX86; [ cups gtk2 libusb1 cairo glib pango atk gdk-pixbuf ];

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

    postFixup = ''
      # UI binaries: FHS interpreter for glibc compat
      patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 \
        $out/bin/thermalprinterui \
        $out/bin/thermalprinterut

      # Filter: needs libcups via dlopen at hardcoded FHS paths.
      # Wrap it so it runs inside the FHS env (and, cross-arch, through FEX).
      mv $out/lib/cups/filter/rastertobarcodetspl \
         $out/lib/cups/filter/.rastertobarcodetspl-wrapped
      cat > $out/lib/cups/filter/rastertobarcodetspl << EOF
      #!/bin/sh
      exec ${fhsEnv}/bin/tscdriver-fhs \
        ${execPrefix}$out/lib/cups/filter/.rastertobarcodetspl-wrapped "\$@"
      EOF
      chmod +x $out/lib/cups/filter/rastertobarcodetspl

      for b in brusb brsocket; do
        mv $out/lib/cups/backend/$b \
           $out/lib/cups/backend/.$b-wrapped
        cat > $out/lib/cups/backend/$b << EOF
      #!/bin/sh
      exec ${fhsEnv}/bin/tscdriver-fhs \
        ${execPrefix}$out/lib/cups/backend/.$b-wrapped "\$@"
      EOF
        chmod +x $out/lib/cups/backend/$b
      done
    '';
  };

  fhsEnv = pkgsX86.buildFHSEnv {
    name = "tscdriver-fhs";
    targetPkgs =
      ps: with ps; [
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
  inherit version;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -vdm755 $out/bin

    for bin in thermalprinterui thermalprinterut; do
      cat > $out/bin/$bin << EOF
    #!/bin/sh
    exec ${fhsEnv}/bin/tscdriver-fhs ${execPrefix}${tscdriver-unwrapped}/bin/$bin "\$@"
    EOF
      chmod +x $out/bin/$bin
    done

    ln -s ${tscdriver-unwrapped}/lib $out/lib
    ln -s ${tscdriver-unwrapped}/share $out/share

    runHook postInstall
  '';

  meta = with lib; {
    description = "Drivers for TSC Printers";
    homepage = "https://www.tscprinters.com";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}

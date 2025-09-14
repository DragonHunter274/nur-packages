{ lib
, stdenv
, fetchFromGitHub
, libsForQt5
, pkg-config
, bluez
, openssl
, dbus
, udev
, libusb1
, git
}:

let
  variants = [
    "original"
    "platinum"
    "gold"
    "silver"
    "bronze"
    "free"
  ];

  # Function to create a package for a specific variant
  makeVariant = variant: libsForQt5.mkDerivation {
    pname = if variant == "original" then "vesc-tool" else "vesc-tool-${variant}";
    # Since there are no tags, we'll use a date-based version format
    version = "unstable-2025-02-27"; # Current date as version

    src = fetchFromGitHub {
      owner = "vedderb";
      repo = "vesc_tool";
      # Use a specific commit hash instead of master
      rev = "044fa33"; # Specific commit from Feb 2024
      # You'll need to update this hash when changing the commit
      sha256 = "sha256-LNXMMeKsHKYOm+dkM9pzX/nP7QP+aEiLk2RrE4P45S0=";
      #sha256 = lib.fakeSha256;
    };

    nativeBuildInputs = [
      pkg-config
      git # Needed for the build process
      libsForQt5.wrapQtAppsHook # Essential for Qt applications
    ];

    buildInputs = [
      libsForQt5.qtbase
      libsForQt5.qtserialport
      libsForQt5.qtcharts
      libsForQt5.qtsvg
      libsForQt5.qtquickcontrols2
      libsForQt5.qtpositioning
      libsForQt5.qtgamepad
      libsForQt5.qtconnectivity
      libsForQt5.qtdeclarative   # Provides QtQuick
      libsForQt5.qtquickcontrols # Provides QtQuickWidgets
      libsForQt5.qtwayland       # May be needed for some Qt features
      bluez
      openssl
      dbus
      udev
      libusb1
    ];

    # Set up Git information for the build
    preBuild = ''
      # Create a fake git environment to satisfy the version check
      git init
      git config --local user.email "builder@localhost"
      git config --local user.name "Nix Builder"
      git add .
      git commit -m "Fake commit for build" --no-gpg-sign || true
      
      # Create empty firmware directories to avoid the missing files error
      mkdir -p res/firmwares_esp/ESP32-C3/Express\ Plus/
      touch res/firmwares_esp/ESP32-C3/Express\ Plus/partition-table.bin
    '';

    # Work around resource issues
    NIX_LDFLAGS = "-lX11";
    
    # Don't use the default configure/build phases
    dontUseQmakeConfigure = true;
    
    buildPhase = ''
      runHook preBuild
      
      # Export Qt bin path so qmake can be found
      export PATH=$PATH:${libsForQt5.qtbase.dev}/bin
      
      echo "========== Building VESC Tool (${variant}) =========="
      echo "Current directory: $(pwd)"
      
      # Show Qt version info
      qmake --version
      
      # Configure for this variant exactly as done in the original script
      echo "Running qmake..."
      qmake -config release "CONFIG += release_lin build_${variant} exclude_fw" DEFINES+=SKIP_FIRMWARE
      
      # Build without clean (clean not needed in a fresh Nix build)
      echo "Building with make..."
      make -j$NIX_BUILD_CORES
      
      # Show what was built
      echo "Build output:"
      find build/lin -type f
      
      # Remove object files to reduce size
      rm -rf build/lin/obj
      
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      
      # Create bin directory
      mkdir -p $out/bin
      
      # Look for the versioned executable and create a standard symlink
      echo "Looking for VESC Tool executable..."
      VESC_EXEC=$(find build/lin -name "vesc_tool_*" -type f -executable | head -1)
      
      if [ -n "$VESC_EXEC" ]; then
        echo "Found executable: $(basename $VESC_EXEC)"
        cp "$VESC_EXEC" $out/bin/vesc_tool
        chmod +x $out/bin/vesc_tool
      elif [ -f "build/lin/vesc_tool" ]; then
        echo "Found standard vesc_tool executable"
        cp build/lin/vesc_tool $out/bin/vesc_tool
        chmod +x $out/bin/vesc_tool
      else
        echo "ERROR: Could not find vesc_tool executable!"
        echo "Contents of build/lin:"
        ls -la build/lin/
        exit 1
      fi
      
      # Copy any additional files that might be needed
      find build/lin -type f -not -path "*/obj/*" -not -name "vesc_tool*" -exec cp {} $out/bin/ \; || true
      
      # Create a desktop entry
      mkdir -p $out/share/applications
      cat > $out/share/applications/vesc-tool${if variant != "original" then "-${variant}" else ""}.desktop << EOF
[Desktop Entry]
Type=Application
Name=VESC Tool${if variant != "original" then " (${variant})" else ""}
Comment=Tool for VESC motor controllers
Exec=$out/bin/vesc_tool
Icon=$out/share/icons/hicolor/512x512/apps/vesc_tool.png
Categories=Development;Electronics;
EOF
      
      # Copy the icon if it exists
      if [ -f "res/icon.png" ]; then
        mkdir -p $out/share/icons/hicolor/512x512/apps
        cp res/icon.png $out/share/icons/hicolor/512x512/apps/vesc_tool.png
      fi
      
      runHook postInstall
    '';

    # Add this attribute to prevent the fixup phase from stripping some necessary files
    dontPatchELF = true;
    
    meta = with lib; {
      description = "Tool for VESC motor controllers${if variant != "original" then " (${variant} variant)" else ""}";
      longDescription = ''
        VESC Tool is a configuration and diagnostic tool for VESC motor controllers.
        ${if variant != "original" then "This is the ${variant} variant of the tool, which may have different feature sets depending on the variant." else ""}
      '';
      homepage = "https://github.com/vedderb/vesc_tool";
      license = licenses.gpl3;
      platforms = platforms.linux;
      maintainers = with maintainers; [ ];
      mainProgram = "vesc_tool"; # This tells nix run which executable to use
    };
  };

in makeVariant "original"

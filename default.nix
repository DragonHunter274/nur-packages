# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> { } }:


let
  lib = import ./lib { inherit pkgs; };
  gnome-keyring = pkgs.nixos.gnome.gnome-keyring; # Correctly reference gnome-keyring
in
{
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  example-package = pkgs.callPackage ./pkgs/example-package { };
  mtkclient = pkgs.callPackage ./pkgs/mtkclient { };
  openbeken-flasher = pkgs.callPackage ./pkgs/openbeken-flasher { };
  bitwarden-desktop = pkgs.callPackage ./pkgs/bitwarden-desktop/package.nix {
    inherit (pkgs) lib dbus electron_32 glib gtk3 libsecret nodejs_20;
    gnome-keyring = gnome-keyring; # Pass it to the package
  };
  # some-qt5-package = pkgs.libsForQt5.callPackage  ./pkgs/some-qt5-package { };
  # ...
}

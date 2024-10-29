{ pkgs ? import <nixpkgs> { } }:

let
  lib = import ./lib { inherit pkgs; };
  gnome-keyring = pkgs.gnome.gnome-keyring; # Correctly reference gnome-keyring
in
{
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  example-package = pkgs.callPackage ./pkgs/example-package { };
  mtkclient = pkgs.callPackage ./pkgs/mtkclient { };
  openbeken-flasher = pkgs.callPackage ./pkgs/openbeken-flasher { };
  
  bitwarden-desktop = pkgs.callPackage ./pkgs/bitwarden-desktop/package.nix {
    gnome-keyring = gnome-keyring; # Pass it to the package
  };
}

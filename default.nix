{ pkgs ? import <nixpkgs> { } }:

  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  example-package = pkgs.callPackage ./pkgs/example-package { };
  mtkclient = pkgs.callPackage ./pkgs/mtkclient { };
  openbeken-flasher = pkgs.callPackage ./pkgs/openbeken-flasher { };
  
  bitwarden-desktop = pkgs.callPackage ./pkgs/bitwarden-desktop/package.nix { 
   inherit (pkgs) gnome-keyring;
 };
}

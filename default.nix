{ pkgs ? import <nixpkgs> { } }:
{
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  example-package = pkgs.callPackage ./pkgs/example-package { };
  mtkclient = pkgs.callPackage ./pkgs/mtkclient { };
  openbeken-flasher = pkgs.callPackage ./pkgs/openbeken-flasher { };
  rofi-nixsearch = pkgs.callPackage ./pkgs/rofi-nix-search/package.nix { };  
  docker-credential-ghcr-login = pkgs.callPackage ./pkgs/docker-credential-ghcr-login { };
  bitwarden-desktop = pkgs.callPackage ./pkgs/bitwarden-desktop/package.nix { 
   gnome-keyring = pkgs.gnome-keyring;
 };
}

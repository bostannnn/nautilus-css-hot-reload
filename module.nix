# NixOS module for Nautilus CSS hot-reload
{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [ (import ./overlay.nix) ];
}

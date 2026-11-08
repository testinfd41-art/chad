{ config, lib, pkgs, ... }:

{
  imports = [
    ./apps/filem.nix
    ./apps/firefox.nix
    ./apps/chromium.nix
    ./apps/theme.nix
    ./apps/spotify.nix
  ];
}

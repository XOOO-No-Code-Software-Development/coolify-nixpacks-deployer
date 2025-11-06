# Nix packages configuration
# Matches the packages from nixpacks.toml

{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/bc8f8d1be58e8c8383e683a06e1e1e57893fff87.tar.gz") {} }:

with pkgs;

buildEnv {
  name = "xooo-backend-env";
  paths = [
    curl
    jq
    python311
    python311Packages.pip
    wget
  ];
}

# Copied from https://github.com/ElvishJerricco/nixpkgs/tree/installer-small

{ system, pkgs }: let
  inherit (import (pkgs.path + /nixos/lib/testing-python.nix) { inherit system pkgs; }) runTest;
in {
  simple = runTest ./simple.nix;
}

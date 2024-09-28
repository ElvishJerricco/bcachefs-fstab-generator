# Copied from https://github.com/ElvishJerricco/nixpkgs/tree/installer-small

{ system, pkgs }: let
  inherit (import (pkgs.path + /nixos/lib/testing-python.nix) { inherit system pkgs; }) runTest;
in {
  simple = runTest ./simple.nix;
  encrypted = runTest ./encrypted.nix;
  credential = runTest ./credential.nix;
  gptAuto = runTest ./gpt-auto.nix;
  gptAutoEncrypted = runTest ./gpt-auto-encrypted.nix;
  gptAutoCredential = runTest ./gpt-auto-credential.nix;
}

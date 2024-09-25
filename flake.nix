{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, self }: let
    systems = ["x86_64-linux" "aarch64-linux"];
  in {
    packages = nixpkgs.lib.genAttrs systems (system: {
      default = (import nixpkgs { inherit system; overlays = [ self.overlays.default ]; }).bcachefs-fstab-generator;
    });

    overlays.default = import ./overlay.nix;

    nixosModules.default = ./module.nix;

    checks = nixpkgs.lib.genAttrs systems (system: {
      inherit (nixpkgs.legacyPackages.${system}.callPackage ./tests {}) simple;
    });
  };
}

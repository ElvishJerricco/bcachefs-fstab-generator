{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, self }: {
    packages = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: {
      default = (import nixpkgs { inherit system; overlays = [ self.overlays.default ]; }).bcachefs-fstab-generator;
    });

    overlays.default = import ./overlay.nix;

    nixosModules.default = ./module.nix;
  };
}

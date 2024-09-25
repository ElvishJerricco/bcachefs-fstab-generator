{ lib, rustPlatform, rustfmt, pkg-config, systemd }:

rustPlatform.buildRustPackage {
  pname = "bcachefs-fstab-generator";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./LICENSE
      ./src
    ];
  };
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ rustfmt pkg-config ];
  buildInputs = [ systemd ];
}

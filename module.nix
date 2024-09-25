{ lib, config, pkgs, ... }: {
  nixpkgs.overlays = [ (import ./overlay.nix) ];

  boot.initrd.systemd.contents."/etc/systemd/system-generators/bcachefs-fstab-generator".source =
    "${pkgs.bcachefs-fstab-generator}/bin/bcachefs-fstab-generator";

  boot.initrd.systemd.services."bcachefs-unlock@" = {
    overrideStrategy = "asDropin";
    path = [ pkgs.bcachefs-tools config.boot.initrd.systemd.package ];
    serviceConfig.ExecSearchPath = lib.makeBinPath [ pkgs.bcachefs-tools ];
  };

  systemd.generators.bcachefs-fstab-generator =
    "${pkgs.bcachefs-fstab-generator}/bin/bcachefs-fstab-generator";

  systemd.services."bcachefs-unlock@" = {
    overrideStrategy = "asDropin";
    path = [ pkgs.bcachefs-tools config.systemd.package ];
    serviceConfig.ExecSearchPath = lib.makeBinPath [ pkgs.bcachefs-tools ];
  };
}

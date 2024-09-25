{ lib, pkgs, ... }: let
  diskLayout = builtins.toFile "disk-layout" ''
    label: gpt
    label-id: c0660c98-914c-4eb0-812f-1cf92c9e5945

    size=512MiB, type="EFI System", uuid=ed62cdd4-addc-4f0d-9a8c-9755018ae3fc
                 type="linux",      uuid=3f4bb431-10b5-4657-a7dd-9db61295c20d
  '';
in {
  name = "simple";
  imports = [./common.nix];

  nodes.installer.systemd.services.format = {
    requiredBy = ["nixos-install.service"];
    before = ["nixos-install.service"];
    serviceConfig.Type = "oneshot";
    path = [pkgs.dosfstools pkgs.bcachefs-tools pkgs.util-linux];
    script = ''
      sfdisk /dev/vda < ${diskLayout}
      udevadm settle
      mkfs.vfat /dev/disk/by-partuuid/ed62cdd4-addc-4f0d-9a8c-9755018ae3fc
      mkfs.bcachefs /dev/disk/by-partuuid/3f4bb431-10b5-4657-a7dd-9db61295c20d
      mkdir /mnt
      mount /dev/disk/by-partuuid/3f4bb431-10b5-4657-a7dd-9db61295c20d /mnt
      mkdir /mnt/boot
      mount /dev/disk/by-partuuid/ed62cdd4-addc-4f0d-9a8c-9755018ae3fc /mnt/boot
    '';
  };
  nodes.target = { config, ... }: {
    boot.initrd.systemd.services.unlock-bcachefs--.enable = false;
    virtualisation.fileSystems = lib.mkForce {
      "/" = {
        device = "PARTUUID=3f4bb431-10b5-4657-a7dd-9db61295c20d";
        fsType = "bcachefs";
      };
      "/boot" = {
        device = "PARTUUID=ed62cdd4-addc-4f0d-9a8c-9755018ae3fc";
        fsType = "vfat";
      };
    };
  };
}

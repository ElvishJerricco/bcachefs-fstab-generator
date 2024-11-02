{ lib, pkgs, ... }: let
  type = {
    x64 = "4f68bce3-e8cd-4db1-96e7-fbcaf984b709";
    aa64 = "b921b045-1df0-41c3-af44-4c6f280d3fae";
  }.${pkgs.hostPlatform.efiArch};

  diskLayout = builtins.toFile "disk-layout" ''
    label: gpt
    label-id: c0660c98-914c-4eb0-812f-1cf92c9e5945

    size=512MiB, type="EFI System", uuid=ed62cdd4-addc-4f0d-9a8c-9755018ae3fc
                 type="${type}",    uuid=3f4bb431-10b5-4657-a7dd-9db61295c20d
  '';
in {
  name = "gpt-auto-encrypted";
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
      echo -n somepass | bcachefs format --encrypted /dev/disk/by-partuuid/3f4bb431-10b5-4657-a7dd-9db61295c20d
      echo -n somepass | bcachefs unlock -k session /dev/disk/by-partuuid/3f4bb431-10b5-4657-a7dd-9db61295c20d
      mkdir /mnt
      mount /dev/disk/by-partuuid/3f4bb431-10b5-4657-a7dd-9db61295c20d /mnt
      mkdir /mnt/boot
      mount /dev/disk/by-partuuid/ed62cdd4-addc-4f0d-9a8c-9755018ae3fc /mnt/boot
    '';
  };
  nodes.target = { config, ... }: {
    boot.initrd.systemd.services.unlock-bcachefs--.enable = false;
    boot.initrd.systemd.root = "gpt-auto";
    boot.kernelParams = [ "rootfstype=bcachefs" ];
    boot.initrd.systemd.managerEnvironment.SYSTEMD_DISSECT_FILE_SYSTEMS = "bcachefs";
    virtualisation.fileSystems = lib.mkForce { };
  };

  testing.bcachefs.encryption = {
    enable = true;
    passphrase = "somepass";
  };
}

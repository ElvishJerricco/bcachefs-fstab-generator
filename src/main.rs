use anyhow::{bail, Context, Result};
use fstab::FsTab;
use std::env;
use std::fs;
use std::io::ErrorKind;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use systemd::unit;

fn cmdline_gpt_auto() -> Result<bool> {
    let text = env::var("SYSTEMD_PROC_CMDLINE")
        .unwrap_or(fs::read_to_string("/proc/cmdline").context("Failed to read /proc/cmdline")?);
    Ok(Some("root=gpt-auto")
        == text
            .split_whitespace()
            .filter(|arg| arg.starts_with("root="))
            .last())
}

fn sd_escape_path<P: AsRef<Path>, S: Into<String>>(path: &P, suffix: S) -> Result<String> {
    let path = path.as_ref();
    let path_str = path
        .strip_prefix("/")
        .context(format!("Path is not absolute: {}", path.display()))?
        .to_str()
        .context(format!("Couldn't convert path to str: {}", path.display()))?;
    Ok(format!("{}{}", unit::escape_name(path_str), suffix.into()))
}

fn device_to_path(device: String) -> Result<PathBuf> {
    if let Some(uuid) = device.strip_prefix("UUID=") {
        return Ok(Path::new("/dev/disk/by-uuid")
            .join(Path::new(uuid))
            .to_path_buf());
    }
    if let Some(label) = device.strip_prefix("LABEL=") {
        return Ok(Path::new("/dev/disk/by-label")
            .join(Path::new(label))
            .to_path_buf());
    }
    if let Some(partuuid) = device.strip_prefix("PARTUUID=") {
        return Ok(Path::new("/dev/disk/by-partuuid")
            .join(Path::new(partuuid))
            .to_path_buf());
    }
    if let Some(partlabel) = device.strip_prefix("PARTLABEL=") {
        return Ok(Path::new("/dev/disk/by-partlabel")
            .join(Path::new(partlabel))
            .to_path_buf());
    }
    if device.starts_with("/") {
        return Ok(Path::new(&device).to_path_buf());
    }
    bail!("Failed to convert fs spec to device path: {}", device)
}

fn gen_unit(dest: &Path, device: String, mountpoint: &Path) -> Result<()> {
    let device_path = device_to_path(device)?;
    let device_escaped = sd_escape_path(&device_path, "")?;
    let mountpoint_escaped = sd_escape_path(&mountpoint, ".mount")?;
    let mountpoint_requires = dest.join(format!("{mountpoint_escaped}.requires"));
    let service_name = format!("bcachefs-unlock@{device_escaped}.service");
    let mountpoint_display = mountpoint.display();

    fs::create_dir_all(dest).context(format!("Failed to create directory: {}", dest.display()))?;
    fs::write(
        dest.join(&service_name),
        format!(
            "\
[Unit]
Description=Unlock bcachefs file system {mountpoint_display}
Requires=%i.device
After=%i.device systemd-makefs@%i.service
Before={mountpoint_escaped} systemd-fsck@%i.service

[Service]
Type=oneshot
ExecCondition=bcachefs unlock -c %f
ExecStart=/bin/sh -c 'systemd-ask-password Unlock bcachefs encryption: {mountpoint_display} | exec bcachefs unlock %f'
"
        ),
    )
    .context(format!("Failed to write unit: {}", service_name))?;

    let requirement = mountpoint_requires.join(&service_name);
    fs::create_dir_all(&mountpoint_requires).context(format!(
        "Failed to create directory: {}",
        mountpoint_requires.display()
    ))?;
    symlink(&Path::new(&format!("../{service_name}")), &requirement).context(format!(
        "Failed to create requirement symlink: {}",
        requirement.display()
    ))?;

    Ok(())
}

fn initrd_prefix<P: AsRef<Path>>(mountpoint: P) -> Result<PathBuf> {
    let relative = mountpoint
        .as_ref()
        .strip_prefix(Path::new("/"))
        .context(format!(
            "Path is not absolute: {}",
            mountpoint.as_ref().display()
        ))?;
    Ok(Path::new("/sysroot").join(relative))
}

fn run(dest: &Path, fstab: &Path, in_initrd: bool) -> Result<()> {
    let entries = match FsTab::new(fstab).get_entries() {
        Ok(entries) => entries,
        Err(err) => {
            return match err.kind() {
                ErrorKind::NotFound => Ok(()),
                _ => Err(err.into()),
            }
        }
    };

    let gpt_auto = if in_initrd && cmdline_gpt_auto()? {
        Some(("/dev/gpt-auto-root".to_string(), PathBuf::from("/sysroot")))
    } else {
        None
    };

    entries
        .iter()
        .filter(|e| e.vfs_type == "bcachefs")
        .filter(|e| !in_initrd || e.mount_options.contains(&"x-initrd.mount".to_string()))
        // Add /sysroot prefix in initrd
        .map(|e| {
            let full_mountpoint = if in_initrd {
                initrd_prefix(&e.mountpoint).context(format!(
                    "Failed to add /sysroot prefix to: {}",
                    e.mountpoint.display()
                ))?
            } else {
                e.mountpoint.clone()
            };
            Ok((e.fs_spec.clone(), full_mountpoint))
        })
        // Collect errors
        .collect::<Result<Vec<_>>>()?
        .into_iter()
        .chain(gpt_auto.into_iter())
        .try_for_each(|(device, mountpoint)| gen_unit(dest, device, mountpoint.as_path()))
}

fn main() -> Result<()> {
    let arg = env::args()
        .skip(1)
        .next()
        .context("Expected one argument")?;
    let dest = Path::new(&arg);

    if env::var("SYSTEMD_IN_INITRD")
        .map(|v| ["1", "yes", "on", "true"].contains(&v.as_str()))
        .unwrap_or(Path::new("/etc/initrd-release").exists())
    {
        run(
            &dest,
            &Path::new(
                &env::var("SYSTEMD_SYSROOT_FSTAB").unwrap_or("/sysroot/etc/fstab".to_string()),
            ),
            true,
        )
        .context("run initrd")?;
    }

    run(
        &dest,
        &Path::new(&env::var("SYSTEMD_FSTAB").unwrap_or("/etc/fstab".to_string())),
        false,
    )
    .context("run")?;

    Ok(())
}

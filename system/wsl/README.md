# Arch WSL setup

Run [Setup.ps1](Setup.ps1) from the repository root in normal PowerShell 7:

```powershell
.\system\wsl\Setup.ps1 -LinuxUser holybaechu
```

Use `-Repository https://github.com/yourname/dotfiles.git` for a fork. Setup installs WSL2 and
Arch if absent, provisions the Linux account, and selects Arch and that user as the defaults.
If Windows returns a restart requirement, restart and rerun with the same arguments.

## Provisioning ownership

[provision.sh](provision.sh) bootstraps Ansible and handles the interactive password prompt.
[provision.yml](provision.yml) owns official packages, the full Arch upgrade, the account,
password-required sudo, and a Windows executable interop check. WSL manages the executable
registration; provisioning removes the obsolete systemd-binfmt override. [yay.yml](yay.yml)
builds yay as the Linux user and installs it as root; no passwordless sudo is needed. No AUR
applications are automatically installed.

The user block applies Linux dotfiles through chezmoi, then installs the configured Bun, Node
LTS, and uv through mise. Their versions are declared in
[home/](../../home/dot_config/mise/modify_config.toml), rather than repeated in Ansible. Windows
and WSL keep separate checkouts; existing checkouts and account home directories are preserved.

## Retry or update

Resolve the failed command or task shown in the output and rerun `Setup.ps1`. Existing passwords
and installed yay are retained. Reprovisioning includes a full system upgrade; read the
[Arch upgrade guidance](https://wiki.archlinux.org/title/System_maintenance#Upgrading_the_system)
first on older installations. Setup does not pull the existing Linux dotfiles checkout.
Update and apply it separately as described in [Maintenance](../../docs/maintenance.md).

If the Windows executable interop check fails, ensure `[interop] enabled=true` in `/etc/wsl.conf`,
then run `wsl --terminate archlinux` from PowerShell and retry setup. Terminating Arch stops its
running Linux processes.

For ordinary application-setting changes, use `chezmoi diff` and `chezmoi apply` inside WSL.
That path does not provision the system or upgrade packages.

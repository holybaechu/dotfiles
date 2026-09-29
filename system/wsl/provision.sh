#!/usr/bin/env bash
set -euo pipefail

linux_user=${1:?Linux username is required}
repository=${2:?Dotfiles repository is required}
if [[ $EUID -ne 0 || ! $linux_user =~ ^[a-z_][a-z0-9_-]{0,31}$ || $linux_user == root ]]; then
    printf '%s\n' 'Run as root with a valid non-root Linux username.' >&2
    exit 1
fi

# The official image normally initializes its keyring during interactive OOBE.
pacman-key --init
pacman-key --populate archlinux
# Pacman is only needed to bootstrap yay and its build dependencies.
if ! command -v yay >/dev/null 2>&1; then
    pacman -Sy --needed --noconfirm archlinux-keyring
    pacman -Su --needed --noconfirm git base-devel sudo
fi

if ! id "$linux_user" &>/dev/null; then
    useradd --create-home --groups wheel --shell /bin/bash "$linux_user"
fi
if [[ $(id -u "$linux_user") -eq 0 ]]; then
    printf '%s\n' 'The Linux account must not have UID 0.' >&2
    exit 1
fi

# Require a password for sudo; only initial account setup asks for one.
if [[ $(passwd --status "$linux_user" | awk '{print $2}') != P ]]; then
    printf 'Set the Linux password for %s (used by sudo).\n' "$linux_user"
    passwd "$linux_user"
fi
sudo_rule=$(mktemp)
yay_build_dir=''
trap 'rm -f -- "$sudo_rule"; if [[ -n $yay_build_dir ]]; then rm -rf -- "$yay_build_dir"; fi' EXIT
printf '%s ALL=(ALL:ALL) ALL\n' "$linux_user" > "$sudo_rule"
visudo --check --file "$sudo_rule"
install -m 0440 "$sudo_rule" "/etc/sudoers.d/90-dotfiles-$linux_user"

# Keep Linux's repository and state in the Linux home, separate from Windows.
linux_home=$(getent passwd "$linux_user" | cut -d: -f6)
cd "$linux_home"

if ! command -v yay >/dev/null 2>&1; then
    # makepkg must run as a normal user in a directory that user owns.
    yay_build_dir=$(runuser --user "$linux_user" -- mktemp -d /tmp/dotfiles-yay.XXXXXXXX)
    runuser --user "$linux_user" -- git clone --depth 1 https://aur.archlinux.org/yay.git "$yay_build_dir"
    runuser --user "$linux_user" -- makepkg --dir "$yay_build_dir" --syncdeps --install --noconfirm
fi

# Refresh signing keys before the full upgrade, including on an older image.
runuser --user "$linux_user" -- yay -Sy --needed --noconfirm archlinux-keyring
runuser --user "$linux_user" -- yay -Su --needed --noconfirm --sudoloop chezmoi git github-cli sudo base-devel
runuser --user "$linux_user" -- env GIT_TERMINAL_PROMPT=0 chezmoi init --force --no-tty "$repository"
runuser --user "$linux_user" -- chezmoi apply --force --no-tty

#!/usr/bin/env bash
set -euo pipefail

# Fresh Arch images may name a locale that has not been generated yet.
export LANG=C.UTF-8 LC_ALL=C.UTF-8

linux_user=${1:?Linux username is required}
repository=${2:?Dotfiles repository is required}
if [[ $EUID -ne 0 || ! $linux_user =~ ^[a-z_][a-z0-9_-]{0,31}$ || $linux_user == root ]]; then
    printf '%s\n' 'Run as root with a valid non-root Linux username.' >&2
    exit 1
fi

# Ansible cannot provision its own runtime on a fresh Arch image. The full Arch
# package includes Python and community.general (used for pacman tasks).
if ! pacman -Q ansible >/dev/null 2>&1; then
    pacman-key --init
    pacman-key --populate archlinux
    pacman -Sy --needed --noconfirm archlinux-keyring
    pacman -Su --needed --noconfirm ansible
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_LINUX_USER="$linux_user" DOTFILES_REPOSITORY="$repository" \
    ansible-playbook -i localhost, "$script_dir/provision.yml"

# Keep the interactive password prompt outside Ansible. Existing passwords and
# password-required sudo are preserved; package builds do not need sudo access.
if [[ $(passwd --status "$linux_user" | awk '{print $2}') != P ]]; then
    printf 'Set the Linux password for %s (used by sudo).\n' "$linux_user"
    passwd "$linux_user"
fi

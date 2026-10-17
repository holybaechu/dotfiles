#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    printf '%s\n' 'Run bootstrap as your normal user; package installation uses sudo.' >&2
    exit 1
fi
if ! command -v pacman >/dev/null || ! command -v yay >/dev/null; then
    printf '%s\n' 'This package helper requires pacman and yay. See docs/setup.md for other Linux distributions.' >&2
    exit 1
fi

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mapfile -t packages < "$repository/system/linux/packages.arch"
sudo pacman -Syu --needed "${packages[@]}"
sudo pacman -D --asexplicit "${packages[@]}"
mapfile -t packages < "$repository/system/linux/packages.aur"
yay -S --needed "${packages[@]}"
sudo pacman -D --asexplicit "${packages[@]}"
chezmoi init --source "$repository"

printf '%s\n' 'Package setup finished. Review chezmoi diff, then run chezmoi apply.'

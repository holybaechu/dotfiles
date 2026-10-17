#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    printf '%s\n' 'Run as your normal user; installation uses sudo.' >&2
    exit 1
fi

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/sddm" && pwd)
wallpaper="${XDG_DATA_HOME:-$HOME/.local/share}/backgrounds/canopy.jpg"
if [[ ! -f "$wallpaper" ]]; then
    printf '%s\n' 'Apply the dotfiles first to download the Canopy wallpaper.' >&2
    exit 1
fi
for program in sddm-greeter-qt6 xrandr python3; do
    if ! command -v "$program" >/dev/null; then
        printf 'Install %s before setting up SDDM.\n' "$program" >&2
        exit 1
    fi
done

theme_dir=/usr/local/share/sddm/themes/canopy
sudo install -d -m 755 "$theme_dir" /usr/local/libexec /etc/sddm.conf.d
sudo install -m 644 "$source_dir/canopy/"{Main.qml,metadata.desktop,theme.conf} "$theme_dir/"
sudo install -m 644 "$wallpaper" "$theme_dir/background.jpg"
sudo install -m 755 "$source_dir/setup-monitors.py" /usr/local/libexec/sddm-canopy-monitors
# Select the theme only after its files are in place.
sudo install -m 644 "$source_dir/sddm.conf" /etc/sddm.conf.d/20-canopy.conf
printf '%s\n' 'SDDM theme and monitors installed. Reboot when ready to use them.'

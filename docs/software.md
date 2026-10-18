# Software

| Purpose | Software |
| --- | --- |
| Desktop and shortcuts | [Hyprland](https://hypr.land/) |
| Login screen | [SDDM with Canopy](sddm.md) |
| Bar, launcher, panels, notifications | Custom [Canopy](desktop.md) with [Quickshell](https://quickshell.org/) |
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) |
| Shell and prompt | Fish, Fisher (`done`, `autopair.fish`), Starship |
| File manager | [Yazi](https://yazi-rs.github.io/) in Kitty |
| Archives | [PeaZip](https://peazip.github.io/) and 7-Zip |
| Browser | [Helium](https://helium.computer/) |
| Media | mpv with mpv-mpris; playerctl for media keys |
| Apple Music | [Cider](https://cider.sh/) (license required) |
| Editor | [Neovim](neovim.md) |
| Git and SSH signing | Git, 1Password |
| Desktop application credentials | GNOME Keyring |
| Korean input | [Fcitx5 with Hangul](desktop.md#korean-input) |
| Fonts | Monaspace Neon NF, Inter, Noto CJK |
| Application appearance | adw-gtk3, GTK 4 Canopy colors, qt6ct with a Canopy palette |
| File listing, man pages, search | eza, bat, ripgrep, fd |
| System summary | Fastfetch |
| Runtime management | mise: Bun, Node.js LTS, uv |
| Configuration | chezmoi for home files; Ansible for system setup |

Package manifests: [pacman packages](../system/linux/packages.arch),
[AUR packages](../system/linux/packages.aur), and
[packages removed by bootstrap](../system/linux/packages.remove). The Ansible
playbook uses pacman/yay; the managed settings do not source distribution
configuration.

Canopy searches desktop entries and filenames directly with `fd`; no separate
file indexer is required. MIME defaults select Helium, Yazi, PeaZip, and mpv,
preserving unrelated entries in `mimeapps.list`. Yazi opens text files in Neovim.

## Runtimes and uv

Mise owns the versions declared in the
[managed configuration](../home/dot_config/mise/modify_config.toml).
Run from your home directory to avoid project overrides:

```sh
mise install bun node uv
mise upgrade bun node uv
```

Fish activates mise automatically. Remove conflicting standalone Bun or nvm/fnm
installations after verifying the new tools. Existing Python environments, caches,
and global npm packages are not migrated automatically.

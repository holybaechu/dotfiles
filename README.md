# Dotfiles

Personal Linux desktop configuration, managed with [chezmoi](https://www.chezmoi.io/)
for home files and [Ansible](https://docs.ansible.com/) for system setup.
Uses Hyprland, a custom Quickshell Canopy shell, Fish, Kitty, and Neovim.

Start with [Setup](docs/setup.md). Review `chezmoi diff` before applying: it replaces
managed shell and desktop settings. Configuration has no CachyOS dependency;
the system playbook supports Arch and its derivatives.

- [Desktop and Canopy](docs/desktop.md)
- [Neovim](docs/neovim.md)
- [Maintenance](docs/maintenance.md)
- [Software](docs/software.md)

[home/](home/) is the chezmoi source. [system/linux/](system/linux/) contains
the Ansible playbook and package lists; [bootstrap.sh](bootstrap.sh) runs system setup.

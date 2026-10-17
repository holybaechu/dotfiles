# Maintenance

## Dotfiles

Edit [home/](../home/), then preview and apply:

```sh
chezmoi diff
chezmoi apply
```

`.chezmoiroot` restricts deployment to `home/`. System packages and services are
separate from chezmoi. GitHub CLI credentials remain local.

| Tool | Reload |
| --- | --- |
| Fish | Open a new terminal; `fisher update` updates plugins |
| Hyprland | `Super+Shift+O` or `hyprctl reload` |
| Canopy | Quickshell reloads edited QML automatically |
| Kitty | `Ctrl+Shift+F5` reloads configuration |
| Yazi | `ya emit-to 0 app:theme` reloads the theme |
| GTK and Qt | Restart applications after applying appearance changes |
| Neovim | Restart; see [plugin updates](neovim.md#update-plugins-and-language-tools) |

Canopy commands and its safe preview are documented in [Desktop](desktop.md#canopy).
Canopy starts with Qt's QML disk cache disabled so edits do not reuse stale code.
Changes to root shell pragmas, including native-menu support, require restarting Canopy.
Update packages with your distribution's package manager; update managed language
runtimes with the commands in [Software](software.md#runtimes-and-uv).

Check monitor targeting, failed brightness changes, and hardware timeouts with
`python3 -m unittest discover -s tests`. These tests use mocked commands and
temporary device files.

## Fish

| Shortcut | Action |
| --- | --- |
| `ls` / `ll` | eza with icons / long listing |
| `la` | Long listing including hidden files |
| `lt` | Directory tree with icons |
| `..` / `...` / `....` | Go up one / two / three directories |

Manual pages use bat. Fish starts with Fastfetch's bundled compact `examples/32`
preset; Starship renders the prompt and replaces Pure's rendering hook if Pure
is installed. Autosuggestions use Fish defaults.
`done` uses Canopy's notification service. The managed plugin list is
[fish_plugins](../home/dot_config/fish/fish_plugins).

Fish and Hyprland export `SSH_AUTH_SOCK=~/.1password/agent.sock`; SSH also sets
`IdentityAgent` directly. See [authentication setup](setup.md#git-authentication).

## Yazi

Kitty supports dragging files directly between Yazi and desktop applications.
Select multiple files with `Space`, then drag the selection into the destination
app. See [Yazi's drag-and-drop guide](https://yazi-rs.github.io/docs/dnd/).

## Recovery

Before an initial apply, keep a copy of the existing managed config directories.
Restore those copies from a TTY if the new desktop cannot start. This repository
does not automatically remove programs or old unmanaged configuration files.

For a later unwanted source change, save local work, restore the affected source
file from a known Git revision, inspect `chezmoi diff`, and apply only its target:

```sh
git restore --source=<known-good-revision> -- home/dot_config/kitty/kitty.conf
chezmoi diff ~/.config/kitty/kitty.conf
chezmoi apply ~/.config/kitty/kitty.conf
```

Check `git diff` before committing; use Conventional Commit messages as described
in [AGENTS.md](../AGENTS.md).

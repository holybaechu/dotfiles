# Neovim

Requires Neovim 0.12+. Configuration: [home/dot_config/nvim/](../home/dot_config/nvim/).
Space is the leader key.

## First launch

1. Restart the terminal after bootstrap to load the installed tools.
2. Open `nvim` with internet access. Plugins, parsers, language servers, and StyLua install automatically.
3. Check `:Mason` for tool installation progress.

Configure servers in [lsp.lua](../home/dot_config/nvim/lua/plugins/lsp.lua),
formatters in [formatting.lua](../home/dot_config/nvim/lua/plugins/formatting.lua),
and parsers in [treesitter.lua](../home/dot_config/nvim/lua/plugins/treesitter.lua).
ESLint requires a project's ESLint configuration and dependency. Formatting is manual.

If Windows opens with defaults, check `:echo stdpath('config')` and `:echo $MYVIMRC`
in a regular PowerShell terminal, then apply the managed Neovim files there.

## Editing

- Hardtime disables arrow keys and the mouse. Use `:Hardtime toggle`, `:Hardtime disable`, or `:Hardtime report`.
- Completion combines LSP, paths, snippets, and buffer words. Use Tab / Shift+Tab to move through snippet fields.
- MiniSurround: `saiw"` quotes a word, `sd"` removes quotes, and `sr"'` changes them to single quotes.
- MiniAi: `cia` changes an argument; `vif` selects inside a function call.
- MiniMove: `Space m` then `h/j/k/l` moves a line or selection.
- Folds start open. Use `za` to toggle and `:TSUpdate` to retry parser updates.

## Sessions and undo

Sessions are saved explicitly, separately on each OS, under `stdpath("state")/sessions`.
They preserve the project layout, not unsaved text or terminal processes.
Restoration refuses to discard unsaved buffers.

In Undotree, use `j/k` and Enter to select a state, `u` to undo, and `D` to toggle the diff.
Git pickers browse history without switching branches.

## Copilot

Run `:Copilot auth` in a code file, separately on Windows and WSL.
Use `:Copilot disable` / `:Copilot enable` to toggle suggestions.
Suggestions hide while the completion menu is open; Enter and Tab retain their usual behavior.

## Appearance

The [Canopy colorscheme](../home/dot_config/nvim/colors/canopy.lua) uses a transparent
canvas and solid panels. Increase Windows Terminal opacity for more contrast.
Reload with `:colorscheme canopy` after editing.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Space ff` / `Space fg` | Find files / search project text |
| `Space fb` / `Space fh` | Find buffers / search help |
| `Space fd` / `Space fo` | Find diagnostics / recent files |
| `Space fs` / `Space fS` / `Space fr` | Find document symbols / workspace symbols / references |
| `Space e` | Browse files; press `g?` for browser help |
| `Space w` | Save the current buffer |
| `Space` then pause / `Space ?` | Show leader shortcuts / buffer-local shortcuts |
| `Ctrl+h/j/k/l` | Move between split windows |
| `Ctrl+n` / `Ctrl+p` | Select the next / previous completion |
| `Ctrl+y` / `Enter` | Accept an explicitly selected completion; Enter otherwise inserts a newline |
| `Ctrl+Space` / `Ctrl+e` | Open / dismiss completion |
| `Ctrl+b` / `Ctrl+f` | Scroll completion documentation |
| `Tab` / `Shift+Tab` (Insert or Select mode) | Next / previous field in the active LuaSnip snippet |
| `sa` / `sd` / `sr` | Add / delete / replace surroundings |
| `Space mh/j/k/l` (Normal or Visual mode) | Move line or selection left / down / up / right |
| `Space ss` / `Space sr` | Save / restore the project session |
| `Space sl` / `Space sd` | Select / delete a saved session |
| `Space u` | Toggle undo history |
| `za` / `zo` / `zc` | Toggle / open / close a fold |
| `Alt+a` / `Alt+w` / `Alt+s` (Insert mode) | Accept the Copilot suggestion / next word / next line |
| `Alt+.` / `Alt+,` (Insert mode) | Next / previous Copilot suggestion |
| `Ctrl+]` (Insert mode) | Dismiss the Copilot suggestion |
| `Ctrl+s` (Insert mode) | Show LSP signature help |
| `gd` / `K` | Go to definition / show hover documentation |
| `Space cr` / `Space ca` / `Space cd` | Rename symbol / code action / line diagnostics |
| `Space cf` | Format the buffer or selected range |
| `]h` / `[h` | Next / previous Git hunk |
| `Space gp` / `Space gb` | Preview Git hunk / toggle line blame |
| `Space gB` / `Space gc` / `Space gh` | Browse Git branches / commits / hunks |

## Update plugins and language tools

Run `:PackUpdate`, then `:write` in its review buffer. Capture the lockfile from WSL:

```sh
chezmoi re-add ~/.config/nvim/nvim-pack-lock.json
```

Commit the lockfile, apply it on the other installation, and run `:PackRestore`.
Mason manages language tools separately. Inspect the setup with `:checkhealth`,
`:CmpStatus`, `:Mason`, and `:ConformInfo`.

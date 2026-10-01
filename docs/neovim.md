# Neovim

Space is the leader key. Start with [first launch](#first-launch-and-language-tools) and the
[shortcut table](#shortcuts).

## Configuration layout

Neovim 0.12+ uses a personal Lua configuration and its built-in `vim.pack` plugin manager. The
shared source is [home/dot_config/nvim/](../home/dot_config/nvim/): `init.lua` loads editor
settings from `lua/config/`, then `lua/plugins/init.lua` loads each feature explicitly. Plugin
declarations and setup stay together in their feature modules.

Chezmoi deploys the shared Lua files to `~/.config/nvim` on both platforms. On Windows, a small
entry point in `%LOCALAPPDATA%\nvim` loads those files, and a template copies the shared plugin
lockfile into that native configuration directory. Each OS keeps its own installed plugins and
tools in Neovim's data directory.

### If Windows opens with defaults

Apply the Windows configuration from a regular PowerShell terminal. Packaged desktop automation
can redirect AppData writes into an application-specific cache, leaving the normal Neovim config
directory empty. If Neovim opens with defaults, check `:echo stdpath('config')` and `:echo
$MYVIMRC` in that same terminal, then apply the managed Neovim files there.

## Features

| Feature | Configuration |
| --- | --- |
| Theme | Standalone Canopy High Contrast colorscheme |
| File search and browser | MiniPick and MiniFiles; ripgrep for project search |
| Completion | nvim-cmp with LSP, file-path, LuaSnip, and current-buffer sources |
| Snippets | LuaSnip and friendly-snippets, with cmp_luasnip for completion |
| Editing | MiniSurround, MiniAi text objects, and MiniPairs automatic pairs |
| Motion practice | Hardtime with repeated-key restrictions and motion hints |
| Keybinding help | WhichKey with Canopy styling and leader-key groups |
| Statusline | MiniStatusline with mode, Git changes, diagnostics, LSP, and file information |
| Extended search | MiniExtra pickers for diagnostics, symbols, references, recent files, and Git history |
| Sessions | MiniSessions with explicit project snapshots in each OS's local state directory |
| Undo history | Undotree with a diff preview and persistent Neovim undo history |
| Syntax and folding | nvim-treesitter parsers and native Tree-sitter highlighting/folds |
| AI suggestions | copilot.lua with automatic inline suggestions |
| Language support | Native LSP and nvim-lspconfig; Mason installs Lua, TypeScript/JavaScript, ESLint, JSON, HTML, and CSS servers |
| Formatting | Conform and StyLua, installed through Mason |
| Git | Gitsigns |

## First launch and language tools

Bootstrap installs Neovim, ripgrep, and Tree-sitter CLI on both platforms. Windows also gets
LLVM MinGW for the C compiler and make; Arch uses base-devel, curl, and unzip. Mason extracts
the Windows Lua tool downloads with PowerShell; Bandizip is the archive app.

1. Restart the terminal after installing tools so Neovim inherits the updated PATH.
2. Open `nvim` with internet access.
3. Check `:Mason` for language-tool installation progress.

On first launch, Neovim installs the plugins recorded in `nvim-pack-lock.json`, builds LuaSnip's
regex support and missing Tree-sitter parsers, then Mason installs the configured language
servers and StyLua.

Node and npm from mise support the JavaScript-based servers. TypeScript Language Server covers
JavaScript, TypeScript, JSX, and TSX; ESLint attaches to projects with an ESLint configuration
and installed ESLint dependency. Add more servers in `lua/plugins/lsp.lua` and formatters in
`lua/plugins/formatting.lua` as needed.

Formatting runs when requested, rather than automatically on save.

## Motion practice

Hardtime starts enabled with its default repeated-key restrictions and motion hints. It disables
arrow keys and mouse support to encourage Vim motions. Use `:Hardtime toggle` to pause or resume
it, `:Hardtime disable` to turn it off, and `:Hardtime report` to review common hints.

## Completion and snippets

Completion offers LSP, file-path, and friendly-snippets suggestions, with current-buffer words
as a fallback. Each menu item shows its source; `[Snippet]` entries are templates loaded for the
current language. LuaSnip expands both templates and language-server snippets.

After accepting a snippet, use Tab / Shift+Tab to move between its fields; Tab otherwise retains
its normal behavior. Signature help is available on request with `Ctrl+s` in Insert mode.

## Syntax and folding

Tree-sitter installs parsers for Bash, CSS, Fish, HTML, JavaScript, JSON (including JSONC), Lua,
Markdown, PowerShell, Python, TOML, TypeScript/TSX, Vim, Vim help, YAML, and queries.
Highlighting and folding start when a supported buffer's parser is available; folds start open,
and `za` toggles one. Add languages in `lua/plugins/treesitter.lua`. Parser updates follow
nvim-treesitter plugin updates automatically; use `:TSUpdate` to retry manually. These parsers
provide syntax support independently of language servers.

## Editing and movement

MiniSurround uses `sa` to add, `sd` to delete, and `sr` to replace surroundings: `saiw"` quotes
a word, `sd"` removes its quotes, and `sr"'` changes double quotes to single quotes.

MiniAi adds argument and function-call text objects; for example, `cia` changes an argument and
`vif` selects the inside of a function call. Its next/previous-object shortcuts are disabled to
preserve Neovim 0.12's native incremental selection.

MiniPairs closes brackets and quotes, removes empty pairs with Backspace, and handles newlines
inside pairs through cmp's Enter fallback.

MiniMove moves the current line or visual selection with `Space m` followed by `h/j/k/l`,
avoiding the desktop's Alt shortcuts.

## Sessions

MiniSessions stores named project snapshots under `stdpath("state")/sessions`, separately on
Windows and WSL. `Space ss` saves the current files, tabs, folds, and split layout; `Space sr`
restores the saved snapshot for the current working directory's Git root (or the working
directory outside Git). Names include a path hash so identically named projects do not collide.
`Space sl` selects a saved session and `Space sd` selects one to delete.

Saving and restoration are explicit; restoring refuses to discard unsaved buffers. Sessions do
not back up unsaved file contents, terminal processes, or plugin scratch panels, and they are
not synchronized through chezmoi.

## History and undo

MiniExtra extends the existing picker UI. Its Git branch and commit pickers browse history and
diffs; they do not switch branches or change the repository.

`Space u` opens Undotree, where `j/k` and Enter select a history state, `u` undoes, and `D`
toggles the diff panel. Windows uses the GNU diff bundled with Git for Windows; Arch's
base-devel includes diffutils.

## Copilot

GitHub Copilot uses [copilot.lua](https://github.com/zbirenbaum/copilot.lua)'s native server,
downloaded and checksum-verified on first use (about 75–110 MB per OS); Node.js is not required
on Windows or Arch WSL. Open a code file and run `:Copilot auth` to sign in with a GitHub
account that has Copilot access. Authenticate separately in Windows and WSL; credentials remain
local and are excluded from chezmoi.

Suggestions appear automatically as italic teal inline text and hide while the cmp menu is open.
Accept them with the dedicated shortcuts below; Enter and Tab keep their existing behavior. Use
`:Copilot disable` / `:Copilot enable` to turn Copilot off / on for the session. The separate
suggestion panel is disabled.

## Colors and transparency

The standalone `canopy` colorscheme defines its own editor, syntax, Tree-sitter, semantic-token,
and plugin highlights. It uses Canopy's forest-green surfaces, mint interface accents, and
warm-white text. Syntax roles are separated: lavender keywords, blue functions, mint strings,
teal types, and amber numbers. Errors are red, warnings amber, information blue, and hints
green; diagnostic signs and messages also identify severity.

The main editor canvas is transparent so the managed Windows Terminal profile's acrylic blur
shows through, including when Neovim runs in WSL. Terminal already uses `useAcrylic: true` at
70% opacity. Floating panels, menus, selections, and diagnostic text backgrounds remain solid
for readability. Canvas contrast depends on the content behind the terminal; opacity can be
increased in Terminal for stronger contrast. Other terminals supply their own background
effects. The palette and highlight definitions live in
[colors/canopy.lua](../home/dot_config/nvim/colors/canopy.lua); reload with `:colorscheme
canopy` after editing.

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

Use `:PackUpdate` to review plugin updates, then `:write` in the review buffer to apply them.
Keep the generated lockfile in version control. Update it from WSL and capture it with `chezmoi
re-add ~/.config/nvim/nvim-pack-lock.json`, then commit the source change.

After applying that lockfile on another installation, use `:PackRestore` to review and
synchronize existing plugins to its revisions. Mason's external tools are managed separately
from the plugin lockfile.

## Check the setup

Use `:checkhealth vim.pack`, `:checkhealth vim.lsp`, `:checkhealth nvim-treesitter`,
`:checkhealth which-key`, `:checkhealth luasnip`, `:CmpStatus`, `:Mason`, and `:ConformInfo` to
inspect the setup.

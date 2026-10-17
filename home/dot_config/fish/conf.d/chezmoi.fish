# Interactive colors; shell setup lives in config.fish.
status is-interactive; or return

# Canopy syntax and completion colors match Neovim.
set -g fish_color_normal f0f3e7
set -g fish_color_command aecddd
set -g fish_color_keyword cfb9dd
set -g fish_color_quote bfdc96
set -g fish_color_redirection 9bd1bd
set -g fish_color_end cfb9dd
set -g fish_color_error eea99a
set -g fish_color_param f0f3e7
set -g fish_color_comment aab69e
set -g fish_color_operator f0f3e7
set -g fish_color_escape 9bd1bd
set -g fish_color_autosuggestion aab69e
set -g fish_color_search_match f0f3e7 --background=3c502b
set -g fish_color_selection f0f3e7 --background=3c502b
set -g fish_color_cancel eea99a
set -g fish_color_cwd bfdc96
set -g fish_color_cwd_root eea99a
set -g fish_color_valid_path --underline
set -g fish_color_history_current --bold
set -g fish_pager_color_progress aab69e --background=11160f
set -g fish_pager_color_prefix bfdc96 --bold
set -g fish_pager_color_completion f0f3e7
set -g fish_pager_color_description aab69e
set -g fish_pager_color_selected_background --background=3c502b

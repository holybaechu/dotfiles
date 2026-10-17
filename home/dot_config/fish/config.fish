# Use the 1Password agent for interactive shells and Fish scripts.
set -gx SSH_AUTH_SOCK ~/.1password/agent.sock

status is-interactive; or return

function fish_greeting
    fastfetch --config examples/32.jsonc
end
set -gx MANPAGER 'bat --language=man --plain'

alias ls 'eza --icons=auto --group-directories-first'
alias ll 'eza --long --icons=auto --group-directories-first'
alias la 'eza --long --all --icons=auto --group-directories-first'
alias lt 'eza --tree --icons=auto --group-directories-first'

alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'

if command -q starship
    # Run after plugin snippets so Starship owns prompt rendering.
    functions --erase _pure_prompt_new_line
    starship init fish | source
end

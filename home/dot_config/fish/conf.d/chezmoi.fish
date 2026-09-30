# Interactive defaults managed by chezmoi. Keep local additions in config.fish.
status is-interactive; or return

set -g fish_greeting
set -g fish_autosuggestion_enabled 1

# Use Windows OpenSSH and the 1Password agent, as in the Bash fallback.
alias ssh /mnt/c/Windows/System32/OpenSSH/ssh.exe
alias ssh-add /mnt/c/Windows/System32/OpenSSH/ssh-add.exe

if command -q starship
    starship init fish | source
end

if isatty stdin; and isatty stdout; and command -q fastfetch
    fastfetch
end

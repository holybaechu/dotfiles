# Sourced by interactive Bash shells; keychain reuses one agent across terminals.
[[ $- == *i* ]] || return
export GPG_TTY="$(tty)"
if command -v keychain >/dev/null 2>&1 && [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    eval "$(keychain --eval --quiet id_ed25519)"
fi

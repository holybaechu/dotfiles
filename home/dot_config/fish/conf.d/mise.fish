if command -q mise
    if status is-interactive
        mise activate fish | source
    else
        mise env --shell fish | source
    end
end

# WSL uses the Windows 1Password agent and the Windows SSH configuration.
[[ $- == *i* ]] || return
alias ssh='/mnt/c/Windows/System32/OpenSSH/ssh.exe'
alias ssh-add='/mnt/c/Windows/System32/OpenSSH/ssh-add.exe'

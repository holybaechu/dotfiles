#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    printf '%s\n' 'Run bootstrap as your normal user; Ansible uses sudo for system tasks.' >&2
    exit 1
fi
for program in ansible-playbook ansible-galaxy pacman yay; do
    if ! command -v "$program" >/dev/null; then
        printf 'Install %s before running bootstrap. See docs/setup.md.\n' "$program" >&2
        exit 1
    fi
done

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ansible-galaxy collection install -r "$repository/system/linux/requirements.yml"
exec ansible-playbook -i localhost, "$repository/system/linux/playbook.yml" --ask-become-pass "$@"

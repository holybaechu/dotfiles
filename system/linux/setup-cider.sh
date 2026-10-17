#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    printf '%s\n' 'Run as your normal user; repository setup uses sudo.' >&2
    exit 1
fi
for program in curl gpg pacman-key pacman-conf; do
    if ! command -v "$program" >/dev/null; then
        printf 'Install %s before setting up the Cider repository.\n' "$program" >&2
        exit 1
    fi
done

repositories=$(pacman-conf --repo-list)
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
curl -fsSL https://repo.cider.sh/ARCH-GPG-KEY -o "$temporary/key.asc"
fingerprint=A0CD6B993438E22634450CDD2A236C3F42A61682
downloaded=$(gpg --batch --homedir "$temporary" --with-colons --show-keys "$temporary/key.asc" |
    awk -F: '$1 == "pub" { primary = 1; next } primary && $1 == "fpr" { print $10; primary = 0 }')
if [[ "$downloaded" != "$fingerprint" ]]; then
    printf '%s\n' 'Unexpected Cider signing key; repository configuration is unchanged.' >&2
    exit 1
fi
sudo pacman-key --add "$temporary/key.asc"
sudo pacman-key --lsign-key "$fingerprint"
if ! grep -qx cidercollective <<< "$repositories"; then
    sudo tee -a /etc/pacman.conf >/dev/null <<'EOF'

# Cider Collective Repository
[cidercollective]
SigLevel = Required TrustedOnly
Server = https://repo.cider.sh/arch
EOF
fi
printf '%s\n' 'Cider repository configured. Bootstrap installs Cider with a full system upgrade.'

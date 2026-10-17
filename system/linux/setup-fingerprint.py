#!/usr/bin/env python3
"""Enable fingerprint authentication after a successful scan, or restore PAM."""

import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parent
PAM = Path('/etc/pam.d')
BACKUP = Path('/var/backups/dotfiles-fingerprint')
SERVICES = {'sddm': 'system-login', 'sudo': 'system-auth', 'polkit-1': 'system-auth'}
MODULE = 'dotfiles-fingerprint'


def configure():
    if not Path('/usr/lib/security/pam_fprintd.so').is_file():
        sys.exit('Install fprintd before configuring authentication.')
    changes = {}
    for service, include in SERVICES.items():
        target = PAM / service
        original = target if target.exists() else Path('/usr/lib/pam.d') / service
        text = original.read_text()
        if re.search(r'^auth[ \t]+substack[ \t]+' + MODULE + r'[ \t]*$', text, re.M):
            if not ((BACKUP / service).exists() or
                    (BACKUP / (service + '.absent')).exists()):
                sys.exit(f'Missing original backup for {target}; no files changed.')
            continue
        replacement = f'auth substack {MODULE}'
        if service == 'sddm':
            replacement = ('auth required pam_shells.so\n'
                           'auth requisite pam_nologin.so\n' + replacement)
        text, count = re.subn(r'^auth[ \t]+include[ \t]+' + include + r'[ \t]*$',
                              replacement, text, flags=re.M)
        if count != 1:
            sys.exit(f'Unexpected PAM configuration in {original}; no files changed.')
        changes[target] = text

    # Keep the first originals; rerunning must not overwrite recovery copies.
    module = PAM / MODULE
    content = (SOURCE / 'pam-fingerprint').read_text()
    if module.exists() and module.read_text() != content:
        sys.exit(f'{module} already exists with different contents; no files changed.')
    BACKUP.mkdir(mode=0o700, parents=True, exist_ok=True)
    for target in changes:
        backup = BACKUP / target.name
        absent = BACKUP / (target.name + '.absent')
        if not backup.exists() and not absent.exists():
            if target.exists():
                shutil.copy2(target, backup)
            else:
                absent.touch(mode=0o600)
    for target, text in {module: content, **changes}.items():
        with tempfile.NamedTemporaryFile(mode='w', dir=PAM, delete=False) as file:
            file.write(text)
            temporary = Path(file.name)
        temporary.chmod(0o644)
        temporary.replace(target)
    print(f'Enabled SDDM, sudo, and Polkit fingerprints. Backups: {BACKUP}')


def restore():
    if not BACKUP.is_dir():
        sys.exit('No fingerprint authentication backup exists.')
    for service in SERVICES:
        backup = BACKUP / service
        if backup.exists():
            shutil.copy2(backup, PAM / service)
        elif (BACKUP / (service + '.absent')).exists():
            (PAM / service).unlink(missing_ok=True)
    module = PAM / MODULE
    if module.exists() and module.read_text() == (SOURCE / 'pam-fingerprint').read_text():
        module.unlink()
    print('Restored the original SDDM, sudo, and Polkit PAM configuration.')


def main():
    mode = sys.argv[1:]
    if mode not in ([], ['--apply'], ['--restore']):
        sys.exit(f'Usage: {sys.argv[0]} [--restore]')
    if os.geteuid() == 0:
        if mode == ['--apply']:
            configure()
        elif mode == ['--restore']:
            restore()
        else:
            sys.exit('Run as your normal user to verify your fingerprint first.')
        return
    if mode == ['--apply']:
        sys.exit('Run without --apply to verify your fingerprint first.')
    if not mode:
        if not shutil.which('fprintd-verify'):
            sys.exit('Install the driver and fprintd, then enroll a finger first.')
        print('Scan an enrolled finger to verify it before changing PAM.', flush=True)
        user = pwd.getpwuid(os.getuid()).pw_name
        process = subprocess.Popen(['stdbuf', '-oL', 'fprintd-verify', user],
                                   stdout=subprocess.PIPE, text=True,
                                   env={**os.environ, 'LC_ALL': 'C'})
        matched = False
        for line in process.stdout:
            print(line, end='', flush=True)
            matched |= line.strip() == 'Verify result: verify-match (done)'
        if process.wait() != 0 or not matched:
            sys.exit('Fingerprint verification failed; authentication files are unchanged.')
    subprocess.run(['sudo', 'python3', str(Path(__file__).resolve()),
                    '--restore' if mode else '--apply'], check=True)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Match the Canopy desktop layout before SDDM starts its X11 greeter."""

import re
import subprocess


def monitor_arguments(query):
    laptop = None
    acer = None
    pattern = r'^(\S+) connected[^\n]*\n(.*?)(?=^\S+ (?:dis)?connected|\Z)'
    for match in re.finditer(pattern, query, re.M | re.S):
        name, properties = match.groups()
        if name == 'eDP-1':
            laptop = name
        edid = re.search(r'^[ \t]+EDID:[ \t]*\n((?:[ \t]+[0-9a-fA-F]{32}\n)+)', properties, re.M)
        if edid and b'XV272U W2' in bytes.fromhex(edid[1]):
            acer = name

    args = []
    if acer:
        args += ['--output', acer, '--mode', '2560x1440', '--rate', '144',
                 '--pos', '0x0', '--primary']
    if laptop:
        args += ['--output', laptop, '--mode', '2880x1800', '--rate', '120',
                 '--pos', '2560x0' if acer else '0x0']
        if not acer:
            args += ['--primary']
    return args


if __name__ == '__main__':
    query = subprocess.check_output(['xrandr', '--props'], text=True)
    arguments = monitor_arguments(query)
    if arguments:
        subprocess.run(['xrandr', '--dpi', '96', *arguments], check=True)

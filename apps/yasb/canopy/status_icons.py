def brightness_icon(percent):
    if percent is None:
        return 'monitor'
    return 'sun-dim' if percent <= 33 else 'sun-medium' if percent <= 66 else 'sun'


def volume_icon(percent, muted=False, available=True):
    if not available:
        return 'volume-off'
    if muted:
        return 'volume-x'
    return 'volume' if percent <= 0 else 'volume-1' if percent <= 50 else 'volume-2'


def battery_icon(percent, power_plugged=False):
    if power_plugged:
        return 'battery-charging'
    if percent is None or percent <= 0:
        return 'battery'
    if percent <= 15:
        return 'battery-warning'
    return 'battery-low' if percent <= 35 else 'battery-medium' if percent <= 75 else 'battery-full'

"""Opt-in check of the real OS setting; restores its starting on/off state."""
import os
import time

import pytest

from core.widgets.canopy.system_modes import WindowsModes


def wait_for_saver(driver, expected):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if driver.read('battery_saver') is expected:
            return
        time.sleep(.1)
    assert driver.read('battery_saver') is expected, 'The actual Windows Battery saver state did not change.'


@pytest.mark.skipif(os.environ.get('CANOPY_LIVE_POWER_TEST') != '1',
                    reason='Opt in to temporarily toggle the real Windows Battery saver setting.')
def test_real_battery_saver_switch_and_restore():
    driver = WindowsModes()
    initial = driver.read('battery_saver')
    assert initial is not None
    try:
        driver.write('battery_saver', not initial)
        wait_for_saver(driver, not initial)
        driver.write('battery_saver', initial)
        wait_for_saver(driver, initial)
    finally:
        if driver.read('battery_saver') is not initial:
            driver.write('battery_saver', initial)
            wait_for_saver(driver, initial)

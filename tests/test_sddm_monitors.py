import importlib.util
from pathlib import Path
import unittest


path = Path(__file__).resolve().parents[1] / 'system/linux/sddm/monitors.py'
spec = importlib.util.spec_from_file_location('sddm_monitors', path)
monitors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitors)


def connected(name, model):
    descriptor = (b'\0\0\0\xfc\0' + model.encode().ljust(13, b' ')).ljust(128, b'\0')
    edid = '\n'.join('\t\t' + descriptor[n:n + 16].hex() for n in range(0, 128, 16))
    return f'{name} connected\n\tEDID:\n{edid}\n'


class SddmMonitorsTest(unittest.TestCase):
    def test_acer_is_primary_on_either_connector(self):
        for connector in ['HDMI-1', 'DP-2']:
            with self.subTest(connector=connector):
                query = connected('eDP-1', 'ATNA60HR05-0') + connected(connector, 'XV272U W2')
                args = monitors.monitor_arguments(query)
                self.assertEqual(args, [
                    '--output', connector, '--mode', '2560x1440', '--rate', '144',
                    '--pos', '0x0', '--primary', '--output', 'eDP-1',
                    '--mode', '2880x1800', '--rate', '120', '--pos', '2560x0',
                ])

    def test_laptop_fallback_does_not_configure_an_unrelated_monitor(self):
        query = connected('eDP-1', 'ATNA60HR05-0') + connected('HDMI-1', 'Other monitor')
        self.assertEqual(monitors.monitor_arguments(query), [
            '--output', 'eDP-1', '--mode', '2880x1800', '--rate', '120',
            '--pos', '0x0', '--primary',
        ])

    def test_disconnected_laptop_is_not_enabled(self):
        query = 'eDP-1 disconnected\n' + connected('HDMI-1', 'XV272U W2')
        self.assertEqual(monitors.monitor_arguments(query), [
            '--output', 'HDMI-1', '--mode', '2560x1440', '--rate', '144',
            '--pos', '0x0', '--primary',
        ])


if __name__ == '__main__':
    unittest.main()

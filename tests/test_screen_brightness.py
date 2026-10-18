import importlib.machinery
import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "home/private_dot_local/bin/executable_screen-brightness"
loader = importlib.machinery.SourceFileLoader("screen_brightness", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
brightness = importlib.util.module_from_spec(spec)
loader.exec_module(brightness)


class ScreenBrightnessTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.drm = self.root / "drm"
        self.backlight = self.root / "backlight"
        self.drm.mkdir()
        self.backlight.mkdir()
        for name in ("eDP-1", "HDMI-A-1"):
            connector = self.drm / f"card0-{name}"
            connector.mkdir()
            (connector / "status").write_text("connected\n")
        bus = self.root / "i2c-11"
        bus.mkdir()
        (self.drm / "card0-HDMI-A-1/ddc").symlink_to(bus)
        self.panel = self.drm / "card0-eDP-1/intel_backlight"
        self.panel.mkdir()
        (self.panel / "brightness").write_text("80")
        (self.panel / "max_brightness").write_text("100")
        (self.backlight / "intel_backlight").symlink_to(self.panel)
        for name, value in (("DRM", self.drm), ("BACKLIGHT", self.backlight)):
            replacement = patch.object(brightness, name, value)
            replacement.start()
            self.addCleanup(replacement.stop)
        self.monitors = json.dumps([
            {"name": "eDP-1", "model": "Laptop", "focused": False},
            {"name": "HDMI-A-1", "model": "External", "focused": True},
        ])

    def test_focused_external_display_uses_its_ddc_bus(self):
        for level in (40, 0):
            with self.subTest(level=level), patch.object(brightness, "run", side_effect=[
                self.monitors, "VCP 10 C 80 100\n", "", f"VCP 10 C {level} 100\n"
            ]) as command:
                result = brightness.control("set", level)
                writes = [call.args[0] for call in command.call_args_list if "setvcp" in call.args[0]]
                self.assertEqual(writes, [["ddcutil", "--bus", "11", "setvcp", "10", str(level)]])
                self.assertEqual(result, {"output": "HDMI-A-1", "name": "External", "value": level})
        self.assertEqual((self.panel / "brightness").read_text(), "80")

    def test_explicit_laptop_output_uses_its_backlight(self):
        def command(args):
            if args[0] == "hyprctl":
                return self.monitors
            self.assertEqual(args, ["brightnessctl", "--class", "backlight", "--device", "intel_backlight", "set", "35%"])
            (self.panel / "brightness").write_text("35")
            return ""

        with patch.object(brightness, "run", side_effect=command):
            result = brightness.control("set", 35, "eDP-1")
        self.assertEqual(result["value"], 35)
        self.assertEqual(result["output"], "eDP-1")

    def test_disconnected_external_display_never_falls_back_to_laptop(self):
        (self.drm / "card0-HDMI-A-1/status").write_text("disconnected\n")
        with patch.object(brightness, "run", return_value=self.monitors) as command:
            with self.assertRaisesRegex(RuntimeError, "Cannot identify"):
                brightness.control("set", 40, "HDMI-A-1")
        self.assertEqual(command.call_count, 1)
        self.assertEqual((self.panel / "brightness").read_text(), "80")

    def test_denied_ddc_change_reports_failure(self):
        responses = [self.monitors, "VCP 10 C 80 100\n", RuntimeError("Permission denied")]
        with patch.object(brightness, "run", side_effect=responses):
            with self.assertRaisesRegex(RuntimeError, "Permission denied"):
                brightness.control("set", 40, "HDMI-A-1")

    def test_hardware_command_timeout_is_bounded(self):
        with patch.object(brightness.subprocess, "run", side_effect=subprocess.TimeoutExpired("ddcutil", 3)) as command:
            with self.assertRaisesRegex(RuntimeError, "timed out"):
                brightness.run(["ddcutil", "getvcp", "10"])
        self.assertEqual(command.call_args.kwargs["timeout"], 3)

    def test_popup_does_not_delay_or_fail_a_successful_change(self):
        result = {"output": "HDMI-A-1", "name": "External", "value": 40}
        with patch("sys.argv", [str(SCRIPT), "set", "40"]), patch.object(brightness, "control", return_value=result), \
                patch.object(brightness.subprocess, "run", side_effect=subprocess.TimeoutExpired("quickshell", 0.5)) as popup, \
                patch("sys.stdout", new_callable=io.StringIO):
            self.assertEqual(brightness.main(), 0)
        self.assertEqual(popup.call_args.args[0][-3:], ["HDMI-A-1", "External", "40"])
        self.assertEqual(popup.call_args.kwargs["timeout"], 0.5)

    def test_failed_change_does_not_show_success_popup(self):
        with patch("sys.argv", [str(SCRIPT), "set", "40"]), \
                patch.object(brightness, "control", side_effect=RuntimeError("Permission denied")), \
                patch.object(brightness.subprocess, "run") as popup, patch("sys.stderr", new_callable=io.StringIO):
            self.assertEqual(brightness.main(), 1)
        popup.assert_not_called()


if __name__ == "__main__":
    unittest.main()

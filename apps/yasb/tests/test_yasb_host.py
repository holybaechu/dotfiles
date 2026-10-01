from pathlib import Path
import subprocess
import sys


def test_application_can_quit_while_a_panel_is_expanding():
    result = subprocess.run([sys.executable, str(Path(__file__).with_name('shutdown_probe.py'))], capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, 'An open panel prevented application shutdown.\n' + result.stdout + result.stderr

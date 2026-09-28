from pathlib import Path
import subprocess
import sys

import pytest


@pytest.mark.parametrize('dpr', [1, 1.25, 1.5, 2])
def test_design_scale_preserves_monitor_dpr_and_workspace_hit_target(dpr):
    result = subprocess.run([sys.executable, str(Path(__file__).with_name('scale_probe.py')), str(dpr)],
                            capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, result.stdout + result.stderr

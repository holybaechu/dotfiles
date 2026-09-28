"""Exercise the PowerShell sender against a real Windows named pipe."""
from pathlib import Path
import subprocess
from threading import Thread
from uuid import uuid4

import pytest
import win32file
import win32pipe


SENDER = Path(__file__).resolve().parents[1] / 'ToggleLauncher.ps1'


@pytest.mark.parametrize('acknowledge', [True, False])
def test_sender_ack_and_timeout_leave_whkd_shell_available(acknowledge):
    name = 'canopy-sender-test-' + uuid4().hex
    handle = win32pipe.CreateNamedPipe('\\\\.\\pipe\\' + name, win32pipe.PIPE_ACCESS_DUPLEX,
                                      win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
                                      1, 1024, 1024, 0, None)
    received = []
    errors = []

    def server():
        try:
            win32pipe.ConnectNamedPipe(handle, None)
            received.append(win32file.ReadFile(handle, 1024)[1])
            if acknowledge:
                win32file.WriteFile(handle, b'ACK')
            else:
                # Stay connected without replying; client must time out and close.
                try:
                    win32file.ReadFile(handle, 1024)
                except Exception:
                    pass
        except Exception as error:
            errors.append(error)
        finally:
            win32pipe.DisconnectNamedPipe(handle)
            win32file.CloseHandle(handle)

    worker = Thread(target=server, daemon=True)
    worker.start()
    sender = str(SENDER).replace("'", "''")
    # Same long-lived, line-oriented shell mode used by whkd.
    commands = (f"& '{sender}' -PipeName '{name}' -TimeoutMilliseconds 100\n"
                "Write-Output 'NEXT_SHORTCUT_RAN'\n")
    result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', '-'],
                            input=commands, text=True, capture_output=True, timeout=5)
    worker.join(1)
    assert not worker.is_alive()
    assert not errors
    assert received == [b'toggle-launcher']
    assert 'NEXT_SHORTCUT_RAN' in result.stdout
    assert ('Could not open Canopy launcher' not in result.stdout) == acknowledge
    assert result.returncode == 0, result.stderr

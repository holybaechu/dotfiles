[CmdletBinding()]
param([int]$WezTermProcessId)

$ErrorActionPreference = 'Stop'

# The Lua callback starts this helper directly from the owning WezTerm process.
if (-not $WezTermProcessId) {
    $WezTermProcessId = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
}
if ((Get-Process -Id $WezTermProcessId).ProcessName -ne 'wezterm-gui') {
    throw 'The appearance helper only supports WezTerm GUI processes.'
}

Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public static class WezTermAppearance {
    private delegate bool EnumWindowProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowProc callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder name, int count);
    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll", SetLastError=true)] private static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    public static int Apply(int processId) {
        int count = 0;
        Exception failure = null;
        EnumWindows((hwnd, data) => {
            uint owner;
            GetWindowThreadProcessId(hwnd, out owner);
            if (owner != processId) return true;
            var name = new StringBuilder(256);
            GetClassName(hwnd, name, name.Capacity);
            if (name.ToString() != "org.wezfurlong.wezterm") return true;
            try {
                // Keep WS_CAPTION and WS_THICKFRAME for komorebi/rounding, but
                // remove WS_SYSMENU, WS_MINIMIZEBOX and WS_MAXIMIZEBOX.
                int style = GetWindowLong(hwnd, -16);
                if (SetWindowLong(hwnd, -16, style & ~0x000B0000) == 0)
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                if (!SetWindowPos(hwnd, IntPtr.Zero, 0, 0, 0, 0, 0x0037))
                    throw new Win32Exception(Marshal.GetLastWin32Error());

                // Blur belongs to WezTerm's native startup path; only fix the frame here.
                int corners = 2; // DWMWCP_ROUND
                Marshal.ThrowExceptionForHR(DwmSetWindowAttribute(hwnd, 33, ref corners, 4));
                count++;
            } catch (Exception error) { failure = error; return false; }
            return true;
        }, IntPtr.Zero);
        if (failure != null) throw failure;
        return count;
    }
}
'@

# A newly created GUI window may not be enumerable immediately. Never linger.
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $changed = [WezTermAppearance]::Apply($WezTermProcessId)
    if ($changed -gt 0) { Write-Output "Styled $changed WezTerm window(s)."; exit 0 }
    Start-Sleep -Milliseconds 50
}
throw 'No WezTerm window appeared before the appearance timeout.'

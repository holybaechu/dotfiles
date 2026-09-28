param(
    [ValidateSet('Get', 'Set')][string]$Operation = 'Get',
    [bool]$Enabled = $true
)

$ErrorActionPreference = 'Stop'
if (-not ('Dotfiles.Taskbar' -as [type])) {
    Add-Type -Namespace Dotfiles -Name Taskbar -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct Data {
    public uint cbSize;
    public System.IntPtr hWnd;
    public uint callbackMessage, edge;
    public int left, top, right, bottom;
    public System.IntPtr lParam;
}
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern System.IntPtr FindWindow(string className, string windowName);
[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern System.UIntPtr SHAppBarMessage(uint message, ref Data data);
'@
}

$data = New-Object 'Dotfiles.Taskbar+Data'
$data.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($data)
$data.hWnd = [Dotfiles.Taskbar]::FindWindow('Shell_TrayWnd', $null)
if ($data.hWnd -eq [IntPtr]::Zero) { throw 'The Windows taskbar is unavailable in this session.' }

$state = [Dotfiles.Taskbar]::SHAppBarMessage(4, [ref]$data).ToUInt64()
if ($Operation -eq 'Set' -and [bool]($state -band 1) -ne $Enabled) {
    $data.lParam = [IntPtr]([long]($state -bxor 1))
    [void][Dotfiles.Taskbar]::SHAppBarMessage(10, [ref]$data)
    $state = [Dotfiles.Taskbar]::SHAppBarMessage(4, [ref]$data).ToUInt64()
    if ([bool]($state -band 1) -ne $Enabled) { throw 'Windows did not retain the taskbar auto-hide setting.' }
}
[bool]($state -band 1)

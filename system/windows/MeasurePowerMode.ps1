#requires -Version 7.0
# Select each mode manually in Samsung Settings, then run the identical workload.
# This helper does not change power modes, firmware, drivers, or battery settings.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ModeLabel,
    [Parameter(Mandatory)][scriptblock]$Workload,
    [ValidateRange(3, 10)][int]$Runs = 3
)
$ErrorActionPreference = 'Stop'
if (-not ('Dotfiles.PowerStatus' -as [type])) {
    Add-Type -Namespace Dotfiles -Name PowerStatus -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct Status {
    public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
    public uint BatteryLifeTime, BatteryFullLifeTime;
}
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern bool GetSystemPowerStatus(out Status status);
'@
}
function Assert-PluggedIn {
    $status = New-Object 'Dotfiles.PowerStatus+Status'
    if (-not [Dotfiles.PowerStatus]::GetSystemPowerStatus([ref]$status) -or $status.ACLineStatus -ne 1) {
        throw 'The comparison requires AC power. No power settings were changed.'
    }
}
$times = @()
for ($run = 0; $run -lt $Runs; $run++) {
    Assert-PluggedIn
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & { & $Workload; if (-not $?) { throw 'Workload failed; discard this comparison.' } } | Out-Host
    $watch.Stop()
    Assert-PluggedIn
    $times += $watch.Elapsed.TotalSeconds
}
$sorted = @($times | Sort-Object)
$middle = [int][math]::Floor($Runs / 2)
$median = if ($Runs % 2) { $sorted[$middle] } else { ($sorted[$middle - 1] + $sorted[$middle]) / 2 }
[pscustomobject]@{
    ModeLabel = $ModeLabel; ModeVerification = 'Operator-selected in Samsung Settings; not independently verified'
    Runs = $Runs; Seconds = $times; MedianSeconds = $median
    MinimumSeconds = $sorted[0]; MaximumSeconds = $sorted[-1]
    PowerScheme = (powercfg.exe /getactivescheme) -join ' '
    Notes = 'Compare identical workloads, warm/cold state and AC conditions. Record fan/heat observations separately. Restore the original Samsung mode before returning to battery.'
}

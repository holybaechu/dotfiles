#requires -Version 7.0
# Read-only inventory. Commands are reported as data and are never executed.
[CmdletBinding()]
param([ValidateRange(1, 30)][int]$SampleSeconds = 3)
$ErrorActionPreference = 'Stop'
$issues = [Collections.Generic.List[string]]::new()
$startup = @(Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User)
$tasks = @(Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } | ForEach-Object {
    $task = $_
    try {
        $info = $task | Get-ScheduledTaskInfo
        [pscustomobject]@{ Name = $task.TaskName; Path = $task.TaskPath; Author = $task.Author; State = [string]$task.State
            Actions = @($task.Actions | Select-Object Execute, Arguments); LastRun = $info.LastRunTime; LastResult = $info.LastTaskResult }
    } catch { $issues.Add("Task $($task.TaskName): $($_.Exception.Message)") }
})
$services = @(Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' } | Select-Object Name, DisplayName, State, PathName)
$before = @{}
Get-Process | ForEach-Object { try { $before[$_.Id] = @{ CPU = $_.CPU; Start = $_.StartTime } } catch { $issues.Add("Process $($_.Id): start time unavailable.") } }
Start-Sleep -Seconds $SampleSeconds
$processes = @(Get-Process | ForEach-Object {
    try { $start = $_.StartTime } catch { return }
    if ($before.ContainsKey($_.Id) -and $before[$_.Id].Start -eq $start -and $null -ne $_.CPU) {
        [pscustomobject]@{ Name = $_.ProcessName; Id = $_.Id
            CpuSeconds = [math]::Round([math]::Max(0, $_.CPU - $before[$_.Id].CPU), 3)
            WorkingSetMB = [math]::Round($_.WorkingSet64 / 1MB, 1)
            Publisher = $_.Company; Path = $_.Path }
    }
} | Sort-Object CpuSeconds -Descending | Select-Object -First 20)
[pscustomobject]@{
    CapturedAt = [DateTimeOffset]::Now.ToString('o'); SampleSeconds = $SampleSeconds
    StartupEntries = $startup; ScheduledTasks = $tasks; AutomaticServices = $services; Processes = $processes
    Incomplete = @($issues)
    Limitations = 'A short CPU sample is not proof of sustained cost. Disk/network costs and dependencies require investigation before changes. No entries were disabled.'
}

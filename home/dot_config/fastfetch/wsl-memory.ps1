#requires -Version 5.1
# Empty output is intentional: Fastfetch hides this module when Arch is stopped.
$ErrorActionPreference = 'Stop'

function Invoke-WslRead([string]$Arguments, [Text.Encoding]$Encoding, [int]$TimeoutMs = 1000) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $wsl
    $info.Arguments = $Arguments
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = $Encoding
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMs)) {
            $process.Kill()
            [void]$process.WaitForExit(250)
            return
        }
        if (-not $output.Wait(100) -or -not $errors.Wait(100)) { return }
        if ($process.ExitCode -eq 0) { $output.GetAwaiter().GetResult() }
    } finally {
        $process.Dispose()
    }
}

try {
    $wsl = Get-Command wsl.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Source
    $running = Invoke-WslRead '--list --running --quiet' ([Text.Encoding]::Unicode)
    if (-not $running -or 'archlinux' -notin @($running.Replace([string][char]0, '').Trim() -split '\r?\n' | ForEach-Object { $_.Trim() })) { return }
    $memory = Invoke-WslRead '--distribution archlinux --exec fastfetch --config memory-only.jsonc' ([Text.Encoding]::UTF8) 3000
    if (-not [string]::IsNullOrWhiteSpace($memory)) { $memory.Trim() }
} catch {
    # A startup display must neither block the prompt nor print an error/status row.
}

#requires -Version 5.1
# A fake wsl.exe exercises process encoding, exit handling, and timeouts. No VM is started.
$ErrorActionPreference = 'Stop'
$target = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot))) 'home\dot_config\fastfetch\wsl-memory.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-wsl-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
$savedPath = $env:PATH
$savedMode = $env:DOTFILES_WSL_TEST_MODE
$savedTrace = $env:DOTFILES_WSL_TEST_TRACE
try {
    $fake = Join-Path $scratch 'wsl.exe'
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading;
public class FakeWsl {
    public static int Main(string[] args) {
        string mode = Environment.GetEnvironmentVariable("DOTFILES_WSL_TEST_MODE");
        bool list = args.Length > 0 && args[0] == "--list";
        File.AppendAllText(Environment.GetEnvironmentVariable("DOTFILES_WSL_TEST_TRACE"), list ? "list\n" : "query\n");
        if (list) {
            Console.OutputEncoding = new UnicodeEncoding(false, false);
            if (mode == "stopped") return 0;
            if (mode == "list-failed") return 1;
            Console.WriteLine("archlinux");
            return 0;
        }
        if (mode == "query-failed") return 1;
        if (mode == "timeout") Thread.Sleep(10000);
        Console.OutputEncoding = new UTF8Encoding(false);
        Console.WriteLine("1 GiB / 4 GiB");
        return 0;
    }
}
'@ -OutputAssembly $fake -OutputType ConsoleApplication
    $env:PATH = $scratch + ';' + $savedPath
    $env:DOTFILES_WSL_TEST_TRACE = Join-Path $scratch 'trace.txt'
    foreach ($mode in @('stopped','list-failed','query-failed','timeout','running')) {
        $env:DOTFILES_WSL_TEST_MODE = $mode
        [IO.File]::WriteAllText($env:DOTFILES_WSL_TEST_TRACE, '')
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $output = @(& $target)
        $watch.Stop()
        $trace = Get-Content -LiteralPath $env:DOTFILES_WSL_TEST_TRACE
        if ($mode -in @('stopped','list-failed') -and 'query' -in $trace) { throw 'A stopped/unavailable distro must not be launched.' }
        if ($mode -eq 'running') {
            if (($output -join '') -ne '1 GiB / 4 GiB') { throw 'Running WSL output was lost or decoded incorrectly.' }
        } elseif ($output.Count) { throw "Unexpected output for ${mode}: $output" }
        if ($mode -eq 'timeout' -and $watch.Elapsed.TotalSeconds -gt 3) { throw 'Timed-out query blocked the prompt.' }
        Write-Output "PASS: $mode"
    }
    # Render the real command with a spaced path to catch Windows quoting regressions.
    $mockHome = Join-Path $scratch 'home with spaces'
    $mockHelper = Join-Path $mockHome '.config\fastfetch\wsl-memory.ps1'
    [void](New-Item -ItemType Directory -Path (Split-Path $mockHelper) -Force)
    Copy-Item -LiteralPath $target -Destination $mockHelper
    $dataFile = Join-Path $scratch 'data.json'
    $data = @{chezmoi=@{os='windows';homeDir=$mockHome}} | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText($dataFile, $data, (New-Object Text.UTF8Encoding($false)))
    $template = Join-Path (Split-Path $target) 'config.jsonc.tmpl'
    $rendered = & chezmoi.exe execute-template --override-data-file $dataFile --file $template
    if ($LASTEXITCODE -ne 0) { throw 'Fastfetch template did not render.' }
    $renderedConfig = ($rendered | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json
    $module = @($renderedConfig.modules | Where-Object { $_.type -eq 'command' -and $_.key -eq 'Memory (WSL)' })
    if ($module.Count -ne 1) { throw 'Expected one WSL memory module.' }
    $config = Join-Path $scratch 'fastfetch.json'
    $json = @{logo=@{type='none'};display=@{showErrors=$false};modules=$module} | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($config, $json, (New-Object Text.UTF8Encoding($false)))
    foreach ($mode in @('stopped','running')) {
        $env:DOTFILES_WSL_TEST_MODE = $mode
        [IO.File]::WriteAllText($env:DOTFILES_WSL_TEST_TRACE, '')
        $output = (& fastfetch.exe --config $config --pipe true) -join ''
        if ($LASTEXITCODE -ne 0) { throw 'Fastfetch command failed.' }
        $trace = Get-Content -LiteralPath $env:DOTFILES_WSL_TEST_TRACE
        if ('list' -notin $trace) { throw 'Fastfetch did not run the WSL helper.' }
        if ($mode -eq 'stopped') {
            if (-not [string]::IsNullOrWhiteSpace($output) -or 'query' -in $trace) { throw 'Stopped WSL must remain stopped and have no row or label.' }
        } elseif ($output -ne 'Memory (WSL): 1 GiB / 4 GiB') { throw 'Fastfetch lost the running WSL memory row.' }
        Write-Output "PASS: Fastfetch WSL row when $mode"
    }
} finally {
    $env:PATH = $savedPath
    $env:DOTFILES_WSL_TEST_MODE = $savedMode
    $env:DOTFILES_WSL_TEST_TRACE = $savedTrace
    $resolved = [IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'dotfiles-wsl-test-*') { throw 'Unsafe fixture cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

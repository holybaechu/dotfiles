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
} finally {
    $env:PATH = $savedPath
    $env:DOTFILES_WSL_TEST_MODE = $savedMode
    $env:DOTFILES_WSL_TEST_TRACE = $savedTrace
    $resolved = [IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'dotfiles-wsl-test-*') { throw 'Unsafe fixture cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

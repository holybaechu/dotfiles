#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$PipeName = 'yasb_pipe_cli',
    [ValidateRange(1, 1000)][int]$TimeoutMilliseconds = 100
)

# whkd keeps this PowerShell session alive. Send directly from that session,
# without starting Python, and never wait indefinitely ahead of other shortcuts.
$ErrorActionPreference = 'Stop'
$client = [IO.Pipes.NamedPipeClientStream]::new('.', $PipeName, [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::Asynchronous)
try {
    $client.Connect($TimeoutMilliseconds)
    # Queue the read first: YASB disconnects immediately after sending its ACK.
    $response = New-Object byte[] 64
    $read = $client.ReadAsync($response, 0, $response.Length)
    $request = [Text.Encoding]::UTF8.GetBytes('toggle-launcher')
    $write = $client.WriteAsync($request, 0, $request.Length)
    if (-not $write.Wait($TimeoutMilliseconds)) { throw 'Writing the launcher request timed out.' }
    [void]$write.GetAwaiter().GetResult()
    if (-not $read.Wait($TimeoutMilliseconds)) { throw 'The launcher did not acknowledge the request.' }
    $length = $read.GetAwaiter().GetResult()
    if ([Text.Encoding]::UTF8.GetString($response, 0, $length).Trim() -ne 'ACK') {
        throw 'Restart Canopy to load the launcher command.'
    }
}
catch {
    Write-Warning "Could not open Canopy launcher: $($_.Exception.Message)"
}
finally {
    $client.Dispose()
}

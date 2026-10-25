#requires -Version 7.0
# Downloads, installers and registry changes are mocked; only temporary installer files are written.
$ErrorActionPreference = 'Stop'
$scripts = Join-Path (Split-Path $PSScriptRoot) 'scripts'
$global:BrowserFixture = @{
    Registry = @{}; Writes = 0; Deny = $false; Drop = $false; Downloads = 0; Launches = 0
    Signature = 'Valid'; Signer = 'AT YOUR SIDE INC'; ExitCode = 0; Register = $true
}
$appKey = 'HKLM:\Software\WOW6432Node\Aside\Update\Clients\{822e45a2-1677-4f9e-8052-23cf82713869}'
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Failure([scriptblock]$Action, [string]$Expected) {
    $message = ''
    try { & $Action } catch { $message = $_.Exception.Message }
    Assert ($message -like "*$Expected*") "Expected '$Expected'; got '$message'."
}
function Test-Path {
    [CmdletBinding()]param([string]$LiteralPath)
    if ($LiteralPath -match '^HK(CU|LM):') { return $global:BrowserFixture.Registry.ContainsKey($LiteralPath) }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Get-ItemProperty {
    [CmdletBinding()]param([string]$LiteralPath)
    [pscustomobject]$global:BrowserFixture.Registry[$LiteralPath]
}
function Get-Item {
    [CmdletBinding()]param([string]$LiteralPath)
    $item = [pscustomobject]@{ Data = $global:BrowserFixture.Registry[$LiteralPath] }
    $item | Add-Member ScriptMethod GetValueNames { @($this.Data.Keys) }
    $item | Add-Member ScriptMethod GetValueKind { param($name) $this.Data[$name].Kind }
    $item | Add-Member ScriptMethod GetValue { param($name,$default,$options) $this.Data[$name].Value }
    $item
}
function New-Item {
    [CmdletBinding()]param([string]$Path,[switch]$Force)
    Assert ($Path -eq 'HKLM:\Software\WOW6432Node\Google\Chrome\Extensions\aeblfdkhhhdcdjpifhhbdiojplfjncoa') 'Only the 1Password Web Store registration may be created.'
    $global:BrowserFixture.Registry[$Path] = @{}
}
function New-ItemProperty {
    [CmdletBinding()]param([string]$LiteralPath,[string]$Name,$Value,[string]$PropertyType,[switch]$Force)
    if ($global:BrowserFixture.Deny) { throw 'Registry access denied.' }
    $global:BrowserFixture.Writes++
    if (-not $global:BrowserFixture.Drop) { $global:BrowserFixture.Registry[$LiteralPath][$Name] = @{ Value = $Value; Kind = $PropertyType } }
}
function Invoke-WebRequest {
    [CmdletBinding()]param([string]$Uri,[string]$OutFile)
    Assert ($Uri -eq 'https://aside.com/api/download/windows?arch=x64') 'Only the official Aside installer may be downloaded.'
    $global:BrowserFixture.Downloads++
    [IO.File]::WriteAllText($OutFile, 'mock installer')
}
function Get-AuthenticodeSignature {
    [CmdletBinding()]param([string]$LiteralPath)
    $certificate = [pscustomobject]@{}
    $certificate | Add-Member ScriptMethod GetNameInfo { param($type,$issuer) $global:BrowserFixture.Signer }
    @{ Status = $global:BrowserFixture.Signature; SignerCertificate = $certificate }
}
function Start-Process {
    [CmdletBinding()]param([string]$FilePath,[string[]]$ArgumentList,[string]$WindowStyle,[switch]$Wait,[switch]$PassThru)
    $global:BrowserFixture.Launches++
    if ($global:BrowserFixture.ExitCode -eq 0 -and $global:BrowserFixture.Register) {
        $global:BrowserFixture.Registry[$appKey] = @{ pv = '1.0.1022.1' }
    }
    $process = [pscustomobject]@{ ExitCode = $global:BrowserFixture.ExitCode }
    $process | Add-Member ScriptMethod Dispose { }
    $process
}
try {
    $aside = Join-Path $scripts 'Aside.ps1'
    Assert (-not (& $aside -Operation Get).Installed -and -not (& $aside -Operation Test)) 'An absent browser must not pass detection.'
    Assert ($global:BrowserFixture.Downloads -eq 0) 'Get and Test must not download or install anything.'
    & $aside -Operation Set
    Assert (& $aside -Operation Test) 'A successful browser installation must be detected.'
    & $aside -Operation Set
    Assert ($global:BrowserFixture.Downloads -eq 1 -and $global:BrowserFixture.Launches -eq 1) 'Reapply must keep an existing browser.'
    $global:BrowserFixture.Registry.Remove($appKey)
    $global:BrowserFixture.Signature = 'NotSigned'
    Assert-Failure { & $aside -Operation Set } 'valid AT YOUR SIDE INC signature'
    Assert ($global:BrowserFixture.Launches -eq 1) 'An invalid installer must never run.'
    $global:BrowserFixture.Signature = 'Valid'; $global:BrowserFixture.ExitCode = 5
    Assert-Failure { & $aside -Operation Set } 'exit code 5'
    $global:BrowserFixture.ExitCode = 0; $global:BrowserFixture.Register = $false
    Assert-Failure { & $aside -Operation Set } 'without registering the browser'

    $extension = Join-Path $scripts 'OnePasswordExtension.ps1'
    Assert (-not (& $extension -Operation Get).Exists -and -not (& $extension -Operation Test)) 'An absent extension registration must not pass detection.'
    & $extension -Operation Set
    Assert (& $extension -Operation Test) 'Extension registration must converge.'
    $writes = $global:BrowserFixture.Writes
    & $extension -Operation Set
    Assert ($global:BrowserFixture.Writes -eq $writes) 'Matching registration must not be rewritten.'
    $extensionKey = @($global:BrowserFixture.Registry.Keys | Where-Object { $_ -like '*\Extensions\*' })[0]
    $global:BrowserFixture.Registry[$extensionKey].update_url.Value = 'wrong'
    $global:BrowserFixture.Deny = $true
    Assert-Failure { & $extension -Operation Set } 'Registry access denied'
    $global:BrowserFixture.Deny = $false; $global:BrowserFixture.Drop = $true
    Assert-Failure { & $extension -Operation Set } 'did not retain'
    Write-Output 'PASS: browser reapply, rejected/failed installers and denied/ignored extension registration'
} finally {
    Remove-Variable BrowserFixture -Scope Global
}

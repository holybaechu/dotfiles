#requires -Version 7.0
# Language and input-method changes are isolated in an in-memory fixture.
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path $PSScriptRoot) 'scripts\NalgaesetInputMethod.ps1'
$tip = '0412:{5CC2EDB1-F5F4-456C-A871-CF6B62415CD9}{36207E64-3175-433E-A713-2D0F7473273A}'
$microsoftTip = '0412:{A028AE76-01B1-46C2-99C4-ACD9858AE02F}{B5FE1F02-D5F2-4445-9C03-C568F23C99A1}'
$global:NalgaesetFixture = @{
    Installed = $true; Default = '0409:00000409'; Writes = 0; Deny = $false; Drop = $false
    Languages = @(
        @{ LanguageTag = 'ko'; InputMethodTips = @($microsoftTip) }
        @{ LanguageTag = 'en-US'; InputMethodTips = @('0409:00000409') }
    )
}
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Failure([scriptblock]$Action, [string]$Expected) {
    $message = ''
    try { & $Action } catch { $message = $_.Exception.Message }
    Assert ($message -like "*$Expected*") "Expected '$Expected'; got '$message'."
}
function Test-Path {
    [CmdletBinding()]param([string]$LiteralPath)
    Assert ($LiteralPath -like 'HKLM:\SOFTWARE\Microsoft\CTF\TIP\*') 'Only the Nalgaeset profile may be checked.'
    $global:NalgaesetFixture.Installed
}
function Get-WinUserLanguageList {
    $languages = [Collections.Generic.List[object]]::new()
    foreach ($language in $global:NalgaesetFixture.Languages) {
        $tips = [Collections.Generic.List[string]]::new()
        foreach ($item in $language.InputMethodTips) { $tips.Add($item) }
        $languages.Add([pscustomobject]@{ LanguageTag = $language.LanguageTag; InputMethodTips = $tips })
    }
    ,$languages
}
function Get-WinDefaultInputMethodOverride { [pscustomobject]@{ InputMethodTip = $global:NalgaesetFixture.Default } }
function Set-WinUserLanguageList {
    param($LanguageList, [switch]$Force)
    $global:NalgaesetFixture.Writes++
    if ($global:NalgaesetFixture.Deny) { throw 'Input settings access denied.' }
    if (-not $global:NalgaesetFixture.Drop) { $global:NalgaesetFixture.Languages = $LanguageList }
}
function Set-WinDefaultInputMethodOverride {
    param([string]$InputTip)
    $global:NalgaesetFixture.Writes++
    if ($global:NalgaesetFixture.Deny) { throw 'Input settings access denied.' }
    if (-not $global:NalgaesetFixture.Drop) { $global:NalgaesetFixture.Default = $InputTip }
}
try {
    Assert (-not (& $scriptPath -Operation Test)) 'Unselected Nalgaeset must require configuration.'
    [void](& $scriptPath -Operation Get)
    Assert ($global:NalgaesetFixture.Writes -eq 0) 'Detection must not change input settings.'
    & $scriptPath -Operation Set
    Assert (& $scriptPath -Operation Test) 'Nalgaeset must become an enabled, default input method.'
    $tips = @($global:NalgaesetFixture.Languages | ForEach-Object InputMethodTips)
    Assert ($microsoftTip -in $tips -and '0409:00000409' -in $tips) 'Existing input methods must remain available.'
    $writes = $global:NalgaesetFixture.Writes
    & $scriptPath -Operation Set
    Assert ($global:NalgaesetFixture.Writes -eq $writes) 'Matching input settings must not be rewritten.'
    $global:NalgaesetFixture.Default = '0409:00000409'
    $global:NalgaesetFixture.Deny = $true
    Assert-Failure { & $scriptPath -Operation Set } 'access denied'
    $global:NalgaesetFixture.Deny = $false; $global:NalgaesetFixture.Drop = $true
    Assert-Failure { & $scriptPath -Operation Set } 'did not retain'
    $global:NalgaesetFixture.Installed = $false
    Assert-Failure { & $scriptPath -Operation Set } 'packages module'
    Write-Output 'PASS: input-method selection, preserved fallbacks, safe reapply and denied/ignored settings'
} finally {
    Remove-Variable NalgaesetFixture -Scope Global
}

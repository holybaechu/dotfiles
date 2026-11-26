#requires -Version 5.1
# Shared by the Windows setting resources.
function Get-RegistryState($Setting) {
    if (Test-Path -LiteralPath $Setting.Path) {
        $key = Get-Item -LiteralPath $Setting.Path -ErrorAction Stop
        if ($Setting.Name -in $key.GetValueNames()) {
            return @{ Exists = $true; Kind = $key.GetValueKind($Setting.Name).ToString(); Value = $key.GetValue($Setting.Name, $null, 'DoNotExpandEnvironmentNames') }
        }
    }
    @{ Exists = $false; Kind = $null; Value = $null }
}

function Test-RegistrySetting($Setting) {
    $actual = Get-RegistryState $Setting
    if ($Setting.Kind -eq 'Binary') {
        return $actual.Exists -and $actual.Kind -eq 'Binary' -and
            [BitConverter]::ToString([byte[]]$actual.Value) -ceq [BitConverter]::ToString([byte[]]$Setting.Value)
    }
    $actual.Exists -and $actual.Kind -eq $Setting.Kind -and $actual.Value -ceq $Setting.Value
}

function Set-RegistrySetting($Setting) {
    if (Test-RegistrySetting $Setting) { return }
    if (-not (Test-Path -LiteralPath $Setting.Path)) { [void](New-Item -Path $Setting.Path -Force) }
    [void](New-ItemProperty -LiteralPath $Setting.Path -Name $Setting.Name -Value $Setting.Value -PropertyType $Setting.Kind -Force)
    if (-not (Test-RegistrySetting $Setting)) {
        throw "Windows did not retain $($Setting.Path)\$($Setting.Name)."
    }
}

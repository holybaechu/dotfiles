#requires -Version 5.1
# Shared by the Windows setting resources. Journals contain touched values,
# never commands or arbitrary restore paths: restore uses the caller's allowlist.
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
    $actual.Exists -and $actual.Kind -eq $Setting.Kind -and $actual.Value -ceq $Setting.Value
}

function Read-RegistryJournal([string]$Path) {
    $journal = @{}
    if (Test-Path -LiteralPath $Path) {
        $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $data -or $data -isnot [pscustomobject]) { throw 'Invalid registry rollback journal.' }
        foreach ($property in $data.PSObject.Properties) { $journal[$property.Name] = $property.Value }
    }
    $journal
}

function Save-RegistryJournal([string]$Path, [hashtable]$Journal) {
    $directory = Split-Path $Path
    [void](New-Item -ItemType Directory -Path $directory -Force)
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N')
    try {
        [IO.File]::WriteAllText($temporary, ($Journal | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Set-TrackedRegistryValue($Setting, [string]$JournalPath) {
    if (Test-RegistrySetting $Setting) { return }
    $journal = Read-RegistryJournal $JournalPath
    $id = $Setting.Path + '\' + $Setting.Name
    if (-not $journal.ContainsKey($id)) {
        $journal[$id] = Get-RegistryState $Setting
        Save-RegistryJournal $JournalPath $journal
    }
    if (-not (Test-Path -LiteralPath $Setting.Path)) { [void](New-Item -Path $Setting.Path -Force) }
    [void](New-ItemProperty -LiteralPath $Setting.Path -Name $Setting.Name -Value $Setting.Value -PropertyType $Setting.Kind -Force)
    if (-not (Test-RegistrySetting $Setting)) { throw "Windows did not retain $id." }
}

function Restore-RegistryValues([array]$Settings, [string]$JournalPath) {
    $journal = Read-RegistryJournal $JournalPath
    foreach ($setting in $Settings) {
        $id = $setting.Path + '\' + $setting.Name
        if (-not $journal.ContainsKey($id)) { continue }
        $previous = $journal[$id]
        if ($previous.Exists) {
            if (-not (Test-Path -LiteralPath $setting.Path)) { [void](New-Item -Path $setting.Path -Force) }
            [void](New-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -Value $previous.Value -PropertyType $previous.Kind -Force)
        } elseif ((Get-RegistryState $setting).Exists) {
            Remove-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -ErrorAction Stop
        }
        $restored = Get-RegistryState $setting
        if ($restored.Exists -ne $previous.Exists -or ($previous.Exists -and
            ($restored.Kind -ne $previous.Kind -or ($restored.Value | ConvertTo-Json -Compress) -cne ($previous.Value | ConvertTo-Json -Compress)))) {
            throw "Restore verification failed: $id"
        }
        $journal.Remove($id)
        Save-RegistryJournal $JournalPath $journal
    }
}

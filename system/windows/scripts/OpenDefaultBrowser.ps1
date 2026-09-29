#requires -Version 5.1

$ErrorActionPreference = 'Stop'
if (-not ('Dotfiles.DefaultBrowser' -as [type])) {
    Add-Type -Namespace Dotfiles -Name DefaultBrowser -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shlwapi.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int AssocQueryString(uint flags, uint value, string association,
    string verb, [System.Runtime.InteropServices.Out] System.Text.StringBuilder output, ref uint length);
'@
}

# ASSOCF_IS_PROTOCOL resolves the user's current default; ASSOCSTR_EXECUTABLE
# returns just the executable, so the browser receives no URL or search query.
$flags = 0x1000
$executable = 2
[uint32]$length = 0
$result = [Dotfiles.DefaultBrowser]::AssocQueryString($flags, $executable, 'https', 'open', $null, [ref]$length)
if ($result -lt 0 -or $length -eq 0) {
    throw 'Windows could not find an executable for the default HTTPS browser.'
}

$path = [System.Text.StringBuilder]::new([int]$length)
$result = [Dotfiles.DefaultBrowser]::AssocQueryString($flags, $executable, 'https', 'open', $path, [ref]$length)
if ($result -ne 0 -or -not (Test-Path -LiteralPath $path.ToString() -PathType Leaf)) {
    throw 'Windows could not resolve the default browser executable.'
}

Start-Process -FilePath $path.ToString()

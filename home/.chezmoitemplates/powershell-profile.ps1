{{- $content := .content | replaceAllRegex `(?ms)^# >>> chezmoi starship >>>\r?\n.*?^# <<< chezmoi starship <<<\r?\n?` "" | replaceAllRegex `(?ms)^# >>> chezmoi fastfetch >>>\r?\n.*?^# <<< chezmoi fastfetch <<<\r?\n?` "" | replaceAllRegex `(?ms)^# >>> chezmoi (?:nvm|fnm|mise|colors) >>>\r?\n.*?^# <<< chezmoi (?:nvm|fnm|mise|colors) <<<\r?\n?` "" -}}
{{- $content -}}
{{- if and $content (not (hasSuffix "\n" $content)) }}{{ "\n" }}{{ end -}}
# >>> chezmoi starship >>>
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
# <<< chezmoi starship <<<
# >>> chezmoi colors >>>
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    $canopyEscape = [char]27
    Set-PSReadLineOption -Colors @{
        Default = "$canopyEscape[38;2;240;243;231m"
        Command = "$canopyEscape[38;2;174;205;221m"
        Keyword = "$canopyEscape[38;2;207;185;221m"
        String = "$canopyEscape[38;2;191;220;150m"
        Comment = "$canopyEscape[38;2;170;182;158m"
        Number = "$canopyEscape[38;2;235;201;138m"
        Parameter = "$canopyEscape[38;2;235;201;138m"
        Type = "$canopyEscape[38;2;155;209;189m"
        Member = "$canopyEscape[38;2;155;209;189m"
        Variable = "$canopyEscape[38;2;240;243;231m"
        Operator = "$canopyEscape[38;2;240;243;231m"
        Error = "$canopyEscape[38;2;238;169;154m"
        ContinuationPrompt = "$canopyEscape[38;2;170;182;158m"
        Selection = "$canopyEscape[38;2;240;243;231;48;2;60;80;43m"
    }
    Remove-Variable canopyEscape
}
# <<< chezmoi colors <<<
# >>> chezmoi mise >>>
if (Get-Command mise -CommandType Application -ErrorAction SilentlyContinue) {
    (& mise {{ .miseCommand }}) | Out-String | Invoke-Expression
}
# <<< chezmoi mise <<<
# >>> chezmoi fastfetch >>>
# Only plain console launches; -Command/-File workers must stay quiet.
$fastfetchStartupArgs = @([Environment]::GetCommandLineArgs() | Select-Object -Skip 1 |
    Where-Object { $_ -notin '-NoLogo', '-NoExit' })
if ($Host.Name -eq 'ConsoleHost' -and
    $fastfetchStartupArgs.Count -eq 0 -and
    -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected -and
    (Get-Command fastfetch -CommandType Application -ErrorAction SilentlyContinue)) {
    fastfetch
}
Remove-Variable fastfetchStartupArgs
# <<< chezmoi fastfetch <<<

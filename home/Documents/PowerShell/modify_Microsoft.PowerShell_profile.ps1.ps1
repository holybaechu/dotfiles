{{- /* chezmoi:modify-template */ -}}
{{- $content := .chezmoi.stdin | replaceAllRegex `(?ms)^# >>> chezmoi starship >>>\r?\n.*?^# <<< chezmoi starship <<<\r?\n?` "" | replaceAllRegex `(?ms)^# >>> chezmoi fastfetch >>>\r?\n.*?^# <<< chezmoi fastfetch <<<\r?\n?` "" -}}
{{- $content -}}
{{- if and $content (not (hasSuffix "\n" $content)) }}{{ "\n" }}{{ end -}}
# >>> chezmoi starship >>>
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
# <<< chezmoi starship <<<
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

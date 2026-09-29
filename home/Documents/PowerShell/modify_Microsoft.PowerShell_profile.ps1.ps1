{{- /* chezmoi:modify-template */ -}}
{{- $content := .chezmoi.stdin | replaceAllRegex `(?ms)^# >>> chezmoi starship >>>\r?\n.*?^# <<< chezmoi starship <<<\r?\n?` "" -}}
{{- $content -}}
{{- if and $content (not (hasSuffix "\n" $content)) }}{{ "\n" }}{{ end -}}
# >>> chezmoi starship >>>
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
# <<< chezmoi starship <<<

{{- /* chezmoi:modify-template */ -}}
{{- includeTemplate "powershell-profile.ps1" (dict "content" .chezmoi.stdin "miseCommand" "env --shell pwsh") -}}

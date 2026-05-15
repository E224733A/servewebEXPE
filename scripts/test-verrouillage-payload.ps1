param(
    [string]$BaseUrl = "http://localhost:5088"
)

$ErrorActionPreference = "Stop"

Write-Host "Ce script vérifie seulement que l'application web répond."
Write-Host "Le verrouillage réel est déclenché par le service automatique côté application web."

Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing | Select-Object StatusCode, StatusDescription

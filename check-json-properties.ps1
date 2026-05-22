#!/usr/bin/env pwsh
<#
.DESCRIPTION
Vérifie que les DTOs ont les bonnes propriétés JSON et attributs
#>

# Charge les DTOs pour inspection
$dtoPath = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE\src\MobileSLI.Expedition.Web\Models\ExpeditionDtos.cs"
$content = Get-Content $dtoPath -Raw

# Regex pour extraire les propriétés publiques
$pattern = '\[\s*JsonPropertyName\("(?<name>[^"]+)"\s*\]\s*public\s+(?<type>\S+)\s+(?<prop>\w+)'
$matches = [regex]::Matches($content, $pattern)

Write-Host "`n📋 Propriétés avec JsonPropertyName :" -ForegroundColor Cyan
$matches | ForEach-Object {
    $jsonName = $_.Groups['name'].Value
    $type = $_.Groups['type'].Value
    $prop = $_.Groups['prop'].Value
    Write-Host "  $prop ($type) → `"$jsonName`""
}

# Cherche les propriétés sans JsonPropertyName (qui utiliseront le camelCase par défaut)
$pattern2 = 'public\s+(\S+)\s+(\w+)\s*{\s*get;\s*set;'
$matches2 = [regex]::Matches($content, $pattern2)

Write-Host "`n📋 Propriétés sans JsonPropertyName (utiliseront camelCase) :" -ForegroundColor Yellow
$processed = @()
$matches2 | ForEach-Object {
    $type = $_.Groups[1].Value
    $prop = $_.Groups[2].Value

    # Sauf si déjà trouvé dans matches précédents
    if ($processed -notcontains $prop) {
        $jsonName = $prop | ForEach-Object { [char]::ToLower($_[0]) + $_.Substring(1) }
        Write-Host "  $prop ($type) → `"$jsonName`" (camelCase auto)"
        $processed += $prop
    }
}

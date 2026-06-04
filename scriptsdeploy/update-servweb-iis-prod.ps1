$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================================
# Mise a jour SERVWEB IIS depuis artefact Git - PRODUCTION
# ============================================================
# Ce script ne compile pas sur SERVWEB.
# Il deploie uniquement l'artefact publie dans Git :
# artifacts\servweb\MobileSLI.Expedition.Web.zip
# ============================================================

$SiteName = "MobileSLI.Expedition.Web"
$AppPoolName = "MobileSLI.Expedition.Web"

$SourcePath = "C:\Sources\servewebEXPE"
$ArtifactRelativePath = "artifacts\servweb\MobileSLI.Expedition.Web.zip"
$ManifestRelativePath = "artifacts\servweb\manifest.json"

$PublishPath = "C:\Publish\MobileSLI.Expedition.Web"
$DeployPath = "C:\Services\MobileSLI.Expedition.Web"
$BackupRoot = "C:\Backups\MobileSLI.Expedition.Web"

$ShortWebPort = 80
$ExpeditionHost = "expedition.sli.local"
$AdministrationHost = "admin.sli.local"
$LocalLockHost = "localhost"

$ExpeditionUrl = "http://expedition.sli.local"
$AdministrationUrl = "http://admin.sli.local"
$LocalLockUrl = "http://localhost/verrouillage/executer"
$ApiBaseUrl = "http://api.mobilesli.intra:5000/"
$AspNetEnvironment = "Production"
$FirewallRuleName = "ServeWebEXPE HTTP 80"

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Assert-PathExists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not (Test-Path $Path)) {
        throw "$Message : $Path"
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Invoke-RobocopyChecked {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$ErrorMessage
    )

    robocopy $Source $Destination @Arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -gt 7) {
        throw "$ErrorMessage Code Robocopy=$exitCode"
    }
}

function Sync-GitRepository {
    Write-Step "Mise a jour Git"

    Assert-PathExists $SourcePath "Dossier source introuvable"
    Set-Location $SourcePath

    git status

    Write-Host "SERVWEB est un serveur de deploiement : les modifications locales sont supprimees."

    git fetch origin
    if ($LASTEXITCODE -ne 0) {
        throw "git fetch origin a echoue."
    }

    git reset --hard origin/main
    if ($LASTEXITCODE -ne 0) {
        throw "git reset --hard origin/main a echoue."
    }

    git clean -fd
    if ($LASTEXITCODE -ne 0) {
        throw "git clean -fd a echoue."
    }

    git log -1 --oneline
}

function Expand-Artifact {
    Write-Step "Extraction artefact Git"

    $artifactPath = Join-Path $SourcePath $ArtifactRelativePath
    $manifestPath = Join-Path $SourcePath $ManifestRelativePath

    Assert-PathExists $artifactPath "Artefact Git introuvable. Lance publish-servweb-artifact.ps1 en local puis push"
    Assert-PathExists $manifestPath "Manifest artefact introuvable"

    Write-Host "Artefact : $artifactPath"
    Write-Host "Manifest : $manifestPath"
    Write-Host ""
    Write-Host "--- Manifest artefact ---"
    Get-Content $manifestPath -Raw | Write-Host

    Remove-Item -Recurse -Force $PublishPath -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $PublishPath | Out-Null

    Expand-Archive -Path $artifactPath -DestinationPath $PublishPath -Force

    Assert-PathExists (Join-Path $PublishPath "MobileSLI.Expedition.Web.dll") "DLL publiee introuvable apres extraction"
    Assert-PathExists (Join-Path $PublishPath "web.config") "web.config publie introuvable apres extraction"

    $dll = Get-Item (Join-Path $PublishPath "MobileSLI.Expedition.Web.dll")
    Write-Host "Artefact extrait vers : $PublishPath"
    Write-Host "DLL LastWriteTime     : $($dll.LastWriteTime)"
    Write-Host "DLL Taille Mo         : $([math]::Round($dll.Length / 1MB, 2))"
}

function Backup-CurrentDeployment {
    Write-Step "Sauvegarde version actuelle"

    Ensure-Directory $DeployPath
    Ensure-Directory $BackupRoot

    $backupPath = Join-Path $BackupRoot (Get-Date -Format "yyyyMMdd-HHmmss")
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    Invoke-RobocopyChecked `
        -Source $DeployPath `
        -Destination $backupPath `
        -Arguments @("/MIR", "/R:3", "/W:5", "/XD", "data", "logs", "/XF", "*.log") `
        -ErrorMessage "Sauvegarde robocopy echouee."

    Write-Host "Backup cree : $backupPath"
}

function Enable-AppOffline {
    Write-Step "Mise hors ligne temporaire ASP.NET Core"

    Ensure-Directory $DeployPath
    $appOfflinePath = Join-Path $DeployPath "app_offline.htm"

    @"
<html>
<head><meta charset="utf-8" /><title>Maintenance</title></head>
<body>Application en cours de mise a jour.</body>
</html>
"@ | Set-Content -Path $appOfflinePath -Encoding UTF8

    Start-Sleep -Seconds 5
    Write-Host "app_offline.htm cree : $appOfflinePath"
}

function Disable-AppOffline {
    $appOfflinePath = Join-Path $DeployPath "app_offline.htm"

    if (Test-Path $appOfflinePath) {
        Remove-Item -Path $appOfflinePath -Force -ErrorAction SilentlyContinue
        Write-Host "app_offline.htm supprime."
    }
}

function Deploy-PublishedFiles {
    Write-Step "Copie artefact vers IIS"

    Assert-PathExists $PublishPath "Dossier publish introuvable"
    Ensure-Directory $DeployPath

    Invoke-RobocopyChecked `
        -Source $PublishPath `
        -Destination $DeployPath `
        -Arguments @("/MIR", "/R:3", "/W:5", "/XD", "data", "logs", "scripts", "/XF", "*.log", "app_offline.htm") `
        -ErrorMessage "Deploiement robocopy echoue."
}

function Ensure-ScheduledLockScript {
    Write-Step "Copie du script de verrouillage planifie"

    $sourceScript = Join-Path $SourcePath "scriptsdeploy\run-verrouillage.ps1"
    $scriptsDeployPath = Join-Path $DeployPath "scripts"
    $destinationScript = Join-Path $scriptsDeployPath "run-verrouillage.ps1"

    Ensure-Directory $scriptsDeployPath

    if (Test-Path $sourceScript) {
        Copy-Item -Path $sourceScript -Destination $destinationScript -Force
        Write-Host "Script verrouillage deploye : $destinationScript"
    }
    else {
        Write-Host "Script source introuvable, conservation du script deja deploye si present : $sourceScript"
    }
}

function New-DefaultWebConfig {
    param([Parameter(Mandatory = $true)][string]$WebConfigPath)

    $content = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet" arguments=".\MobileSLI.Expedition.Web.dll" stdoutLogEnabled="false" stdoutLogFile=".\logs\stdout" hostingModel="inprocess">
        <environmentVariables>
          <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="$AspNetEnvironment" />
          <environmentVariable name="ExpeditionApi__BaseUrl" value="$ApiBaseUrl" />
        </environmentVariables>
      </aspNetCore>
    </system.webServer>
  </location>
</configuration>
"@

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($WebConfigPath, $content, $utf8NoBom)
}

function Get-OrCreate-XmlChild {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)][System.Xml.XmlNode]$Parent,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $child = $Parent.SelectSingleNode($Name)

    if ($null -eq $child) {
        $child = $Document.CreateElement($Name)
        [void]$Parent.AppendChild($child)
    }

    return $child
}

function Set-WebConfigEnvironmentVariable {
    param(
        [Parameter(Mandatory = $true)][xml]$WebConfig,
        [Parameter(Mandatory = $true)][System.Xml.XmlNode]$AspNetCoreNode,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $environmentVariablesNode = Get-OrCreate-XmlChild -Document $WebConfig -Parent $AspNetCoreNode -Name "environmentVariables"
    $existingNode = $null

    foreach ($node in $environmentVariablesNode.SelectNodes("environmentVariable")) {
        if ($node.GetAttribute("name") -eq $Name) {
            $existingNode = $node
            break
        }
    }

    if ($null -eq $existingNode) {
        $existingNode = $WebConfig.CreateElement("environmentVariable")
        $existingNode.SetAttribute("name", $Name)
        $existingNode.SetAttribute("value", $Value)
        [void]$environmentVariablesNode.AppendChild($existingNode)
    }
    else {
        $existingNode.SetAttribute("value", $Value)
    }
}

function Ensure-WebConfigEnvironment {
    param([Parameter(Mandatory = $true)][string]$WebConfigPath)

    Write-Step "Configuration web.config"

    if (-not (Test-Path $WebConfigPath)) {
        Write-Host "web.config introuvable, generation d'un web.config IIS ASP.NET Core."
        New-DefaultWebConfig -WebConfigPath $WebConfigPath
    }

    [xml]$webConfig = Get-Content $WebConfigPath -Raw
    $aspNetCoreNode = $webConfig.SelectSingleNode("//aspNetCore")

    if ($null -eq $aspNetCoreNode) {
        Write-Host "Noeud aspNetCore absent du web.config publie. Remplacement par un web.config IIS ASP.NET Core valide."
        New-DefaultWebConfig -WebConfigPath $WebConfigPath
        [xml]$webConfig = Get-Content $WebConfigPath -Raw
        $aspNetCoreNode = $webConfig.SelectSingleNode("//aspNetCore")
    }

    if ($null -eq $aspNetCoreNode) {
        throw "Impossible de creer un web.config IIS ASP.NET Core valide."
    }

    Set-WebConfigEnvironmentVariable -WebConfig $webConfig -AspNetCoreNode $aspNetCoreNode -Name "ASPNETCORE_ENVIRONMENT" -Value $AspNetEnvironment
    Set-WebConfigEnvironmentVariable -WebConfig $webConfig -AspNetCoreNode $aspNetCoreNode -Name "ExpeditionApi__BaseUrl" -Value $ApiBaseUrl

    $webConfig.Save($WebConfigPath)

    Write-Host "ASPNETCORE_ENVIRONMENT = $AspNetEnvironment"
    Write-Host "ExpeditionApi__BaseUrl = $ApiBaseUrl"
}

function Grant-AppPoolPermissions {
    Write-Step "Droits AppPool sur data, logs et scripts"

    $identity = "IIS AppPool\$AppPoolName"
    $paths = @(
        (Join-Path $DeployPath "data"),
        (Join-Path $DeployPath "logs"),
        (Join-Path $DeployPath "scripts")
    )

    foreach ($path in $paths) {
        Ensure-Directory $path
        icacls $path /grant "${identity}:(OI)(CI)(M)" /T | Out-Host
    }
}

function Ensure-WebBinding {
    param(
        [Parameter(Mandatory = $true)][string]$HostHeader,
        [Parameter(Mandatory = $true)][int]$Port
    )

    Import-Module WebAdministration

    $expectedBinding = "*:${Port}:$HostHeader"

    $existing = Get-WebBinding -Name $SiteName -Protocol "http" -ErrorAction SilentlyContinue |
        Where-Object { $_.bindingInformation -eq $expectedBinding } |
        Select-Object -First 1

    if ($null -eq $existing) {
        New-WebBinding -Name $SiteName -Protocol "http" -IPAddress "*" -Port $Port -HostHeader $HostHeader
        Write-Host "Binding ajoute sur $SiteName : $expectedBinding"
    }
    else {
        Write-Host "Binding deja present sur $SiteName : $expectedBinding"
    }
}

function Ensure-FirewallRule {
    param(
        [Parameter(Mandatory = $true)][string]$RuleName,
        [Parameter(Mandatory = $true)][int]$Port
    )

    Write-Host "Verification pare-feu via netsh : $RuleName"

    $ruleOutput = netsh advfirewall firewall show rule name="$RuleName" 2>&1
    $ruleText = $ruleOutput -join "`n"

    $ruleMissing = $false

    if ($LASTEXITCODE -ne 0) {
        $ruleMissing = $true
    }

    if ($ruleText -match "No rules match" -or $ruleText -match "Aucune r" -or $ruleText -match "Aucune regle" -or $ruleText -match "Aucun") {
        $ruleMissing = $true
    }

    if ($ruleMissing) {
        netsh advfirewall firewall add rule name="$RuleName" dir=in action=allow protocol=TCP localport=$Port | Out-Host

        if ($LASTEXITCODE -ne 0) {
            throw "Impossible d'ajouter la regle pare-feu : $RuleName"
        }

        Write-Host "Regle pare-feu ajoutee : $RuleName"
    }
    else {
        Write-Host "Regle pare-feu deja presente : $RuleName"
    }
}

function Ensure-FinalIisConfiguration {
    Write-Step "Configuration bindings IIS finaux"

    Ensure-WebBinding -HostHeader $ExpeditionHost -Port $ShortWebPort
    Ensure-WebBinding -HostHeader $AdministrationHost -Port $ShortWebPort
    Ensure-WebBinding -HostHeader $LocalLockHost -Port $ShortWebPort
    Ensure-FirewallRule -RuleName $FirewallRuleName -Port $ShortWebPort
}

function Remove-ObsoletePort5100 {
    Write-Step "Suppression des restes du port 5100"

    Import-Module WebAdministration

    $bindings = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue |
        Where-Object { $_.bindingInformation -like "*:5100:*" }

    foreach ($binding in $bindings) {
        Remove-WebBinding -Name $SiteName -Protocol $binding.protocol -BindingInformation $binding.bindingInformation
        Write-Host "Binding port 5100 supprime : $($binding.bindingInformation)"
    }

    $ruleNames = @("ServeWebEXPE HTTP 5100", "SERVWEB HTTP 5100", "MobileSLI Expedition HTTP 5100")

    foreach ($ruleName in $ruleNames) {
        $ruleOutput = netsh advfirewall firewall show rule name="$ruleName" 2>&1
        $ruleText = $ruleOutput -join "`n"

        $ruleExists = $true

        if ($LASTEXITCODE -ne 0) {
            $ruleExists = $false
        }

        if ($ruleText -match "No rules match" -or $ruleText -match "Aucune r" -or $ruleText -match "Aucune regle" -or $ruleText -match "Aucun") {
            $ruleExists = $false
        }

        if ($ruleExists) {
            netsh advfirewall firewall delete rule name="$ruleName" | Out-Host
            Write-Host "Regle pare-feu 5100 supprimee : $ruleName"
        }
    }
}

function Restart-IisApplication {
    Write-Step "Redemarrage IIS"

    Import-Module WebAdministration

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if ($null -eq $site) {
        throw "Site IIS introuvable : $SiteName"
    }

    $appPool = Get-Item "IIS:\AppPools\$AppPoolName" -ErrorAction SilentlyContinue
    if ($null -eq $appPool) {
        throw "AppPool introuvable : $AppPoolName"
    }

    if ($site.State -ne "Started") {
        Write-Host "Site IIS arrete. Demarrage du site : $SiteName"
        Start-Website -Name $SiteName
    }
    else {
        Write-Host "Site IIS deja demarre : $SiteName"
    }

    $appPoolState = (Get-WebAppPoolState -Name $AppPoolName).Value

    if ($appPoolState -eq "Started") {
        Write-Host "AppPool deja demarre. Recyclage : $AppPoolName"
        Restart-WebAppPool -Name $AppPoolName
    }
    else {
        Write-Host "AppPool arrete. Demarrage : $AppPoolName"
        Start-WebAppPool -Name $AppPoolName
    }

    Start-Sleep -Seconds 3

    $finalSite = Get-Website -Name $SiteName
    $finalAppPoolState = (Get-WebAppPoolState -Name $AppPoolName).Value

    if ($finalSite.State -ne "Started") {
        throw "Le site IIS n'est pas demarre apres redemarrage. Etat=$($finalSite.State)"
    }

    if ($finalAppPoolState -ne "Started") {
        throw "L'AppPool n'est pas demarre apres redemarrage. Etat=$finalAppPoolState"
    }

    Write-Host "IIS OK : Site=$($finalSite.State), AppPool=$finalAppPoolState"
}

function Test-HttpEndpoint {
    param([Parameter(Mandatory = $true)][string]$Url)

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 10 -ErrorAction SilentlyContinue
        $statusCode = [int]$response.StatusCode
        $location = $response.Headers["Location"]

        if ($statusCode -ge 200 -and $statusCode -lt 400) {
            Write-Host "[OK] Code=$statusCode Location=$location"
        }
        else {
            Write-Host "[KO] Code=$statusCode Location=$location"
        }
    }
    catch {
        if ($null -ne $_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $location = $_.Exception.Response.Headers["Location"]

            if ($statusCode -ge 200 -and $statusCode -lt 400) {
                Write-Host "[OK] Code=$statusCode Location=$location"
            }
            else {
                Write-Host "[KO] Code=$statusCode Location=$location"
            }
        }
        else {
            Write-Host "[KO] $($_.Exception.Message)"
        }
    }
}

function Run-FinalChecks {
    Write-Step "Tests de verification"

    Import-Module WebAdministration

    Get-Website -Name $SiteName
    Get-WebAppPoolState -Name $AppPoolName

    Write-Host ""
    Write-Host "--- Bindings IIS ---"
    Get-WebBinding -Name $SiteName | Select-Object protocol, bindingInformation | Format-Table -AutoSize

    Write-Host ""
    Write-Host "--- Tests finaux ---"

    $urls = @(
        "http://api.mobilesli.intra:5000/api/health",
        "http://expedition.sli.local",
        "http://admin.sli.local",
        "http://admin.sli.local/expedition",
        "http://expedition.sli.local/administration",
        "http://localhost/preparations/status"
    )

    foreach ($url in $urls) {
        Write-Host ""
        Write-Host "Test HTTP : $url"
        Test-HttpEndpoint -Url $url
    }
}

Write-Step "Mise a jour SERVWEB IIS depuis artefact Git - PRODUCTION"
Write-Host "DNS Expedition final       : $ExpeditionUrl"
Write-Host "DNS Administration final   : $AdministrationUrl"
Write-Host "Endpoint local verrouillage: $LocalLockUrl"
Write-Host "API centrale              : $ApiBaseUrl"
Write-Host "Depot Git                 : $SourcePath"
Write-Host "Artefact Git              : $ArtifactRelativePath"
Write-Host "Dossier publish           : $PublishPath"
Write-Host "Dossier deploy            : $DeployPath"
Write-Host "Environnement ASP         : $AspNetEnvironment"

Write-Step "Chargement du module WebAdministration"
Import-Module WebAdministration

$env:ASPNETCORE_ENVIRONMENT = $AspNetEnvironment
$env:ExpeditionApi__BaseUrl = $ApiBaseUrl

Sync-GitRepository
Expand-Artifact
Backup-CurrentDeployment

try {
    Enable-AppOffline
    Deploy-PublishedFiles
    Ensure-ScheduledLockScript
    Ensure-WebConfigEnvironment -WebConfigPath (Join-Path $DeployPath "web.config")
    Grant-AppPoolPermissions
    Ensure-FinalIisConfiguration
    Remove-ObsoletePort5100
}
catch {
    Write-Step "Erreur pendant le deploiement"
    Write-Host $_.Exception.Message
    Disable-AppOffline
    throw
}

Disable-AppOffline
Restart-IisApplication
Run-FinalChecks

Write-Step "Mise a jour terminee"
Write-Host "URL Expedition finale       : $ExpeditionUrl"
Write-Host "URL Administration finale   : $AdministrationUrl"
Write-Host "Endpoint verrouillage local : $LocalLockUrl"
Write-Host "API centrale DNS            : $ApiBaseUrl"

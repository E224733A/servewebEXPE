#requires -RunAsAdministrator
<#
MISE A JOUR SERVWEB IIS
Version corrigee v3 : correction icacls + web.config sous location/system.webServer
A executer apres chaque modification Git / nouvelle version.

Pre-requis :
- IIS configure avec setup-servweb-iis.ps1
- ASP.NET Core Hosting Bundle .NET 8 installe
- Site IIS MobileSLI.Expedition.Web existant

Execution conseillee :
Set-ExecutionPolicy -Scope Process Bypass -Force
.\update-servweb-iis.ps1
#>

$ErrorActionPreference = "Stop"

# =========================
# Parametres projet
# =========================

$SiteName = "MobileSLI.Expedition.Web"
$AppPoolName = "MobileSLI.Expedition.Web"

$SourcePath = "C:\Sources\servewebEXPE"
$ProjectPath = ".\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj"

$PublishPath = "C:\Publish\MobileSLI.Expedition.Web"
$DeployPath = "C:\Services\MobileSLI.Expedition.Web"
$BackupRoot = "C:\Backups\MobileSLI.Expedition.Web"

$WebPort = 5100
$ServwebIp = "192.168.1.232"
$ApiBaseUrl = "http://192.168.1.233:5000/"
$ApiHealthUrl = "http://192.168.1.233:5000/api/health"
$AspNetCoreEnvironment = "Development"

# =========================
# Fonctions
# =========================

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path $Path)) {
        throw "$Message : $Path"
    }
}

function Import-IisModuleOrStop {
    Write-Step "Chargement du module WebAdministration"

    try {
        Import-Module WebAdministration -ErrorAction Stop
    }
    catch {
        throw @"
Le module WebAdministration est indisponible.
Execute d'abord setup-servweb-iis.ps1 en PowerShell administrateur, puis redemarre SERVWEB si necessaire.

Erreur :
$($_.Exception.Message)
"@
    }

    if (-not (Get-Command Get-Website -ErrorAction SilentlyContinue)) {
        throw "Get-Website indisponible. Execute setup-servweb-iis.ps1 puis redemarre SERVWEB."
    }
}

function Stop-PortProcessIfNeeded {
    param([int]$Port)

    Write-Step "Controle du port $Port"

    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue

    foreach ($listener in $listeners) {
        $pidToStop = $listener.OwningProcess
        if ($pidToStop -eq 0) {
            continue
        }

        $proc = Get-Process -Id $pidToStop -ErrorAction SilentlyContinue
        if (-not $proc) {
            continue
        }

        # Si c'est w3wp, le Stop-Website / Stop-WebAppPool suffit.
        if ($proc.ProcessName -eq "w3wp") {
            continue
        }

        Write-Host "Processus non-IIS detecte sur le port $Port : PID $pidToStop ($($proc.ProcessName)). Arret." -ForegroundColor Yellow
        Stop-Process -Id $pidToStop -Force
        Start-Sleep -Seconds 2
    }
}

function Set-WebConfigEnvironmentVariable {
    param(
        [xml]$Document,
        [System.Xml.XmlElement]$EnvironmentVariablesNode,
        [string]$Name,
        [string]$Value
    )

    $existing = $EnvironmentVariablesNode.SelectSingleNode("environmentVariable[@name='$Name']")

    if ($existing) {
        $existing.SetAttribute("value", $Value)
    }
    else {
        $newNode = $Document.CreateElement("environmentVariable")
        $newNode.SetAttribute("name", $Name)
        $newNode.SetAttribute("value", $Value)
        $EnvironmentVariablesNode.AppendChild($newNode) | Out-Null
    }
}

function Ensure-WebConfigEnvironment {
    param([string]$WebConfigPath)

    Write-Step "Configuration web.config"

    Assert-PathExists $WebConfigPath "web.config introuvable"

    [xml]$webConfig = Get-Content $WebConfigPath

    # Selon le publish ASP.NET Core, system.webServer peut etre :
    # 1) directement sous <configuration>
    # 2) sous <configuration><location path="." inheritInChildApplications="false">
    $systemWebServer = $webConfig.configuration.'system.webServer'

    if (-not $systemWebServer -and $webConfig.configuration.location) {
        $systemWebServer = $webConfig.configuration.location.'system.webServer'
    }

    if (-not $systemWebServer) {
        Write-Host "Contenu actuel de web.config :" -ForegroundColor Yellow
        Get-Content $WebConfigPath | Out-Host
        throw "web.config invalide : section system.webServer introuvable, meme sous configuration/location."
    }

    $aspNetCoreNode = $systemWebServer.aspNetCore

    if (-not $aspNetCoreNode) {
        Write-Host "Contenu actuel de web.config :" -ForegroundColor Yellow
        Get-Content $WebConfigPath | Out-Host
        throw "web.config invalide : noeud aspNetCore introuvable."
    }

    $environmentVariables = $aspNetCoreNode.environmentVariables

    if (-not $environmentVariables) {
        $environmentVariables = $webConfig.CreateElement("environmentVariables")
        $aspNetCoreNode.AppendChild($environmentVariables) | Out-Null
    }

    Set-WebConfigEnvironmentVariable `
        -Document $webConfig `
        -EnvironmentVariablesNode $environmentVariables `
        -Name "ASPNETCORE_ENVIRONMENT" `
        -Value $AspNetCoreEnvironment

    Set-WebConfigEnvironmentVariable `
        -Document $webConfig `
        -EnvironmentVariablesNode $environmentVariables `
        -Name "ExpeditionApi__BaseUrl" `
        -Value $ApiBaseUrl

    $webConfig.Save($WebConfigPath)

    Write-Host "ASPNETCORE_ENVIRONMENT = $AspNetCoreEnvironment"
    Write-Host "ExpeditionApi__BaseUrl = $ApiBaseUrl"
}

function Publish-Application {
    Write-Step "Mise a jour Git et publication Release"

    Assert-PathExists $SourcePath "Dossier source introuvable"

    Set-Location $SourcePath

    git status
    git pull

    dotnet restore $ProjectPath
    if ($LASTEXITCODE -ne 0) { throw "dotnet restore a echoue." }

    dotnet build $ProjectPath -c Release --no-restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet build a echoue. Deploiement annule." }

    Remove-Item $PublishPath -Recurse -Force -ErrorAction SilentlyContinue

    dotnet publish $ProjectPath -c Release -o $PublishPath --no-build
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish a echoue. Deploiement annule." }
}

function Backup-CurrentDeployment {
    Write-Step "Sauvegarde version actuelle"

    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $BackupRoot $timestamp

    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    Write-Host "Backup : $backupPath"

    robocopy $DeployPath $backupPath /MIR /XD data logs /XF *.log
    if ($LASTEXITCODE -gt 7) {
        throw "Sauvegarde robocopy echouee avec le code $LASTEXITCODE."
    }
}

function Deploy-PublishedFiles {
    Write-Step "Copie nouvelle version"

    robocopy $PublishPath $DeployPath /MIR /XD data logs /XF *.log
    if ($LASTEXITCODE -gt 7) {
        throw "Deploiement robocopy echoue avec le code $LASTEXITCODE."
    }
}

function Grant-AppPoolPermissions {
    Write-Step "Droits AppPool sur data et logs"

    $dataPath = Join-Path $DeployPath "data"
    $logsPath = Join-Path $DeployPath "logs"

    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null

    $appPoolIdentity = "IIS AppPool\${AppPoolName}"

    icacls $dataPath /grant "${appPoolIdentity}:(OI)(CI)M" /T | Out-Host
    icacls $logsPath /grant "${appPoolIdentity}:(OI)(CI)M" /T | Out-Host
}

function Restart-IisSite {
    Write-Step "Redemarrage IIS"

    Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
    Stop-WebAppPool -Name $AppPoolName -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2

    Start-WebAppPool -Name $AppPoolName
    Start-Website -Name $SiteName

    Start-Sleep -Seconds 5
}

function Test-Deployment {
    Write-Step "Tests de verification"

    Get-Website -Name $SiteName | Format-Table -AutoSize
    Get-WebAppPoolState -Name $AppPoolName | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Test API centrale : $ApiHealthUrl" -ForegroundColor Yellow
    curl.exe -i $ApiHealthUrl

    Write-Host ""
    Write-Host "Test serveur web local : http://localhost:$WebPort" -ForegroundColor Yellow
    curl.exe -i "http://localhost:$WebPort"

    Write-Host ""
    Write-Host "Test serveur web IP : http://${ServwebIp}:$WebPort" -ForegroundColor Yellow
    curl.exe -i "http://${ServwebIp}:$WebPort"
}

# =========================
# Execution principale
# =========================

Write-Step "Mise a jour SERVWEB IIS"

Write-Host "SERVWEB            : $ServwebIp"
Write-Host "Port web SERVWEB   : $WebPort"
Write-Host "API centrale       : $ApiBaseUrl"
Write-Host "Depot Git          : $SourcePath"
Write-Host "Dossier deploy     : $DeployPath"
Write-Host "Environnement ASP  : $AspNetCoreEnvironment"

Import-IisModuleOrStop

Assert-PathExists $DeployPath "Dossier de deploiement introuvable. Lance d'abord setup-servweb-iis.ps1"

$site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
if (-not $site) {
    throw "Site IIS introuvable : $SiteName. Lance d'abord setup-servweb-iis.ps1"
}

[Environment]::SetEnvironmentVariable("ExpeditionApi__BaseUrl", $ApiBaseUrl, "Machine")
$env:ExpeditionApi__BaseUrl = $ApiBaseUrl

Stop-PortProcessIfNeeded -Port $WebPort
Publish-Application
Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
Stop-WebAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
Backup-CurrentDeployment
Deploy-PublishedFiles
Ensure-WebConfigEnvironment -WebConfigPath (Join-Path $DeployPath "web.config")
Grant-AppPoolPermissions
Restart-IisSite
Test-Deployment

Write-Step "Mise a jour terminee"
Write-Host "URL locale  : http://localhost:$WebPort" -ForegroundColor Green
Write-Host "URL reseau  : http://${ServwebIp}:$WebPort" -ForegroundColor Green
Write-Host "API centrale: $ApiBaseUrl" -ForegroundColor Green

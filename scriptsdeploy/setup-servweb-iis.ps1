#requires -RunAsAdministrator
<#
CONFIGURATION IIS INITIALE - SERVWEB
Version corrigee v3 : correction icacls + web.config sous location/system.webServer
A executer une seule fois sur SERVWEB en PowerShell administrateur.

Contexte :
- SERVWEB = 192.168.1.232
- Port web SERVWEB = 5100
- API = 192.168.1.233:5000
- BaseUrl API = http://192.168.1.233:5000/
- Depot Git = C:\Sources\servewebEXPE
- Securite reseau principale = pare-feu Windows / IIS

Execution conseillee :
Set-ExecutionPolicy -Scope Process Bypass -Force
.\setup-servweb-iis.ps1
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

# Environnement choisi pour la phase actuelle de test :
# Development = HTTP autorise via appsettings.Development.json + bouton developpement disponible.
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

function Invoke-Checked {
    param(
        [scriptblock]$Command,
        [string]$ErrorMessage
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage Code retour : $LASTEXITCODE"
    }
}

function Enable-IisFeatures {
    Write-Step "Activation IIS et outils de scripting"

    if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
        Write-Host "Mode Windows Server detecte : Install-WindowsFeature" -ForegroundColor Yellow

        Install-WindowsFeature `
            Web-Server, `
            Web-Mgmt-Console, `
            Web-Scripting-Tools, `
            Web-Static-Content, `
            Web-Default-Doc, `
            Web-Http-Errors, `
            Web-Http-Logging, `
            Web-Filtering `
            -IncludeManagementTools | Out-Host
    }
    else {
        Write-Host "Mode Windows client detecte : Enable-WindowsOptionalFeature" -ForegroundColor Yellow

        $features = @(
            "IIS-WebServerRole",
            "IIS-WebServer",
            "IIS-ManagementConsole",
            "IIS-ManagementScriptingTools",
            "IIS-StaticContent",
            "IIS-DefaultDocument",
            "IIS-HttpErrors",
            "IIS-HttpLogging",
            "IIS-RequestFiltering"
        )

        foreach ($feature in $features) {
            Write-Host "Activation : $feature" -ForegroundColor Yellow
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Host
        }
    }
}

function Import-IisModuleOrStop {
    Write-Step "Chargement du module WebAdministration"

    try {
        Import-Module WebAdministration -ErrorAction Stop
    }
    catch {
        throw @"
Le module WebAdministration est indisponible apres activation IIS.

Action a faire :
1. Fermer PowerShell.
2. Rouvrir PowerShell en administrateur.
3. Relancer ce script.
4. Si le probleme persiste : redemarrer la VM SERVWEB.

Erreur initiale :
$($_.Exception.Message)
"@
    }

    if (-not (Get-Command Get-Website -ErrorAction SilentlyContinue)) {
        throw "Get-Website reste indisponible. Redemarre la VM SERVWEB puis relance ce script."
    }

    Write-Host "Module WebAdministration OK." -ForegroundColor Green
}

function Ensure-HostingBundle {
    Write-Step "Verification ASP.NET Core Hosting Bundle"

    $module = Get-WebGlobalModule | Where-Object { $_.Name -eq "AspNetCoreModuleV2" }

    if ($module) {
        Write-Host "AspNetCoreModuleV2 OK." -ForegroundColor Green
        return
    }

    Write-Host "AspNetCoreModuleV2 absent. Installation du Hosting Bundle .NET 8 via winget..." -ForegroundColor Yellow

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw @"
winget est indisponible et AspNetCoreModuleV2 est absent.

Installe manuellement le ASP.NET Core Runtime Hosting Bundle .NET 8 sur SERVWEB,
puis redemarre la VM et relance ce script.
"@
    }

    winget install --id Microsoft.DotNet.HostingBundle.8 -e --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Installation du Hosting Bundle .NET 8 echouee. Code retour : $LASTEXITCODE"
    }

    Write-Host "Hosting Bundle installe. Redemarrage IIS..." -ForegroundColor Yellow
    & "$env:SystemRoot\System32\iisreset.exe" /restart | Out-Host

    Import-Module WebAdministration -ErrorAction Stop

    $module = Get-WebGlobalModule | Where-Object { $_.Name -eq "AspNetCoreModuleV2" }

    if (-not $module) {
        throw "AspNetCoreModuleV2 reste absent. Redemarre SERVWEB puis relance ce script."
    }

    Write-Host "AspNetCoreModuleV2 OK apres installation." -ForegroundColor Green
}

function Stop-PortProcessIfNeeded {
    param([int]$Port)

    Write-Step "Liberation du port $Port si necessaire"

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

        Write-Host "Processus detecte sur le port $Port : PID $pidToStop ($($proc.ProcessName))" -ForegroundColor Yellow

        # On libere le port reserve a cette application.
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
    param(
        [string]$WebConfigPath
    )

    Write-Step "Configuration web.config"

    Assert-PathExists $WebConfigPath "web.config introuvable"

    [xml]$webConfig = Get-Content $WebConfigPath

    # Selon le publish ASP.NET Core, system.webServer peut etre :
    # 1) directement sous <configuration>
    # 2) sous <configuration><location path="." inheritInChildApplications="false">
    # Le web.config genere par Microsoft.NET.Sdk.Web utilise souvent le cas 2.
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
        throw "web.config invalide : noeud aspNetCore introuvable. Verifie que dotnet publish a bien genere une application ASP.NET Core."
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

function Ensure-FirewallRule {
    Write-Step "Configuration pare-feu Windows"

    $ruleName = "ServeWebEXPE HTTP 5100"

    $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

    if (-not $existing) {
        New-NetFirewallRule `
            -DisplayName $ruleName `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $WebPort `
            -Action Allow | Out-Host

        Write-Host "Regle pare-feu creee : $ruleName" -ForegroundColor Green
    }
    else {
        Write-Host "Regle pare-feu deja existante : $ruleName"
    }
}

function Publish-Application {
    Write-Step "Publication Release"

    Assert-PathExists $SourcePath "Dossier source introuvable"

    Set-Location $SourcePath

    git status
    git pull

    dotnet restore $ProjectPath
    if ($LASTEXITCODE -ne 0) { throw "dotnet restore a echoue." }

    dotnet build $ProjectPath -c Release --no-restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet build a echoue." }

    Remove-Item $PublishPath -Recurse -Force -ErrorAction SilentlyContinue

    dotnet publish $ProjectPath -c Release -o $PublishPath --no-build
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish a echoue." }
}

function Deploy-PublishedFiles {
    Write-Step "Copie vers dossier de deploiement"

    robocopy $PublishPath $DeployPath /MIR /XD data logs /XF *.log
    if ($LASTEXITCODE -gt 7) {
        throw "robocopy a echoue avec le code $LASTEXITCODE."
    }
}

function Ensure-IisSite {
    Write-Step "Configuration AppPool et site IIS"

    if (-not (Test-Path "IIS:\AppPools\$AppPoolName")) {
        New-WebAppPool -Name $AppPoolName | Out-Null
        Write-Host "AppPool cree : $AppPoolName"
    }
    else {
        Write-Host "AppPool deja existant : $AppPoolName"
    }

    Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name managedRuntimeVersion -Value ""
    Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name startMode -Value "AlwaysRunning"

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue

    if (-not $site) {
        New-Website `
            -Name $SiteName `
            -PhysicalPath $DeployPath `
            -Port $WebPort `
            -IPAddress "*" `
            -HostHeader "" `
            -ApplicationPool $AppPoolName | Out-Null

        Write-Host "Site IIS cree : $SiteName"
    }
    else {
        Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath
        Write-Host "Site IIS deja existant, chemin mis a jour : $SiteName"
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
    Write-Step "Demarrage site IIS"

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

Write-Step "Configuration IIS initiale SERVWEB"

Write-Host "SERVWEB            : $ServwebIp"
Write-Host "Port web SERVWEB   : $WebPort"
Write-Host "API centrale       : $ApiBaseUrl"
Write-Host "Depot Git          : $SourcePath"
Write-Host "Dossier deploy     : $DeployPath"
Write-Host "Environnement ASP  : $AspNetCoreEnvironment"

Enable-IisFeatures
Import-IisModuleOrStop
Ensure-HostingBundle

Write-Step "Creation dossiers"

New-Item -ItemType Directory -Path $PublishPath -Force | Out-Null
New-Item -ItemType Directory -Path $DeployPath -Force | Out-Null
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DeployPath "data") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DeployPath "logs") -Force | Out-Null

Write-Step "Configuration API"

[Environment]::SetEnvironmentVariable("ExpeditionApi__BaseUrl", $ApiBaseUrl, "Machine")
$env:ExpeditionApi__BaseUrl = $ApiBaseUrl

Write-Host "ExpeditionApi__BaseUrl = $ApiBaseUrl"

Stop-PortProcessIfNeeded -Port $WebPort
Publish-Application
Deploy-PublishedFiles
Ensure-WebConfigEnvironment -WebConfigPath (Join-Path $DeployPath "web.config")
Ensure-IisSite
Grant-AppPoolPermissions
Ensure-FirewallRule
Restart-IisSite
Test-Deployment

Write-Step "Configuration terminee"
Write-Host "URL locale  : http://localhost:$WebPort" -ForegroundColor Green
Write-Host "URL reseau  : http://${ServwebIp}:$WebPort" -ForegroundColor Green
Write-Host "API centrale: $ApiBaseUrl" -ForegroundColor Green

#requires -RunAsAdministrator
<#
MISE A JOUR SERVWEB IIS - ETAT FINAL DNS NETTOYE

Etat final attendu :
- http://expedition.sli.local        -> interface Expédition
- http://admin.sli.local             -> interface Administration
- http://admin.sli.local/expedition  -> redirection /administration
- http://expedition.sli.local/administration -> redirection /expedition
- http://localhost/verrouillage/executer -> endpoint technique local pour la tâche Windows 22h35

Le port 5100 n'est plus utilisé.
#>

$ErrorActionPreference = "Stop"

$SiteName = "MobileSLI.Expedition.Web"
$AppPoolName = "MobileSLI.Expedition.Web"
$SourcePath = "C:\Sources\servewebEXPE"
$ProjectPath = ".\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj"
$PublishPath = "C:\Publish\MobileSLI.Expedition.Web"
$DeployPath = "C:\Services\MobileSLI.Expedition.Web"
$BackupRoot = "C:\Backups\MobileSLI.Expedition.Web"

$ShortWebPort = 80
$ExpeditionDns = "expedition.sli.local"
$AdministrationDns = "admin.sli.local"
$LocalLockHost = "localhost"

$ApiDns = "api.mobilesli.intra"
$ApiBaseUrl = "http://${ApiDns}:5000/"
$ApiHealthUrl = "http://${ApiDns}:5000/api/health"

$AspNetCoreEnvironment = "Development"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
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
        Write-Host "Module WebAdministration absent. Tentative d'installation des outils IIS de scripting." -ForegroundColor Yellow

        if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
            Install-WindowsFeature Web-Scripting-Tools -IncludeManagementTools | Out-Host
        }
        elseif (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
            Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementScriptingTools -All -NoRestart | Out-Host
            Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole -All -NoRestart | Out-Host
        }
        else {
            throw "Module WebAdministration indisponible et aucun installateur Windows IIS disponible sur cette machine."
        }

        Import-Module WebAdministration -ErrorAction Stop
    }

    if (-not (Get-Command Get-Website -ErrorAction SilentlyContinue)) {
        throw "Get-Website indisponible après chargement du module WebAdministration."
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
    $systemWebServer = $webConfig.configuration.'system.webServer'
    if (-not $systemWebServer -and $webConfig.configuration.location) {
        $systemWebServer = $webConfig.configuration.location.'system.webServer'
    }
    if (-not $systemWebServer) {
        throw "web.config invalide : section system.webServer introuvable."
    }

    $aspNetCoreNode = $systemWebServer.aspNetCore
    if (-not $aspNetCoreNode) {
        throw "web.config invalide : noeud aspNetCore introuvable."
    }

    $environmentVariables = $aspNetCoreNode.environmentVariables
    if (-not $environmentVariables) {
        $environmentVariables = $webConfig.CreateElement("environmentVariables")
        $aspNetCoreNode.AppendChild($environmentVariables) | Out-Null
    }

    Set-WebConfigEnvironmentVariable -Document $webConfig -EnvironmentVariablesNode $environmentVariables -Name "ASPNETCORE_ENVIRONMENT" -Value $AspNetCoreEnvironment
    Set-WebConfigEnvironmentVariable -Document $webConfig -EnvironmentVariablesNode $environmentVariables -Name "ExpeditionApi__BaseUrl" -Value $ApiBaseUrl

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
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet restore a echoue."
    }

    dotnet build $ProjectPath -c Release --no-restore
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build a echoue."
    }

    Remove-Item $PublishPath -Recurse -Force -ErrorAction SilentlyContinue
    dotnet publish $ProjectPath -c Release -o $PublishPath --no-build
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish a echoue."
    }
}

function Backup-CurrentDeployment {
    Write-Step "Sauvegarde version actuelle"

    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $BackupRoot $timestamp
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    robocopy $DeployPath $backupPath /MIR /XD data logs /XF *.log
    if ($LASTEXITCODE -gt 7) {
        throw "Sauvegarde robocopy echouee avec le code $LASTEXITCODE."
    }
}

function Deploy-PublishedFiles {
    Write-Step "Copie nouvelle version"

    robocopy $PublishPath $DeployPath /MIR /XD data logs scripts /XF *.log
    if ($LASTEXITCODE -gt 7) {
        throw "Deploiement robocopy echoue avec le code $LASTEXITCODE."
    }
}

function Ensure-ScheduledLockScript {
    Write-Step "Copie du script de verrouillage planifie"

    $sourceScript = Join-Path $SourcePath "scriptsdeploy\run-verrouillage.ps1"
    $targetDir = Join-Path $DeployPath "scripts"
    $targetScript = Join-Path $targetDir "run-verrouillage.ps1"

    Assert-PathExists $sourceScript "Script de verrouillage source introuvable"

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Copy-Item -Path $sourceScript -Destination $targetScript -Force

    Write-Host "Script verrouillage déployé : $targetScript" -ForegroundColor Green
}

function Grant-AppPoolPermissions {
    Write-Step "Droits AppPool sur data et logs"

    $dataPath = Join-Path $DeployPath "data"
    $logsPath = Join-Path $DeployPath "logs"
    $scriptsPath = Join-Path $DeployPath "scripts"

    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
    New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null

    $appPoolIdentity = "IIS AppPool\${AppPoolName}"
    icacls $dataPath /grant "${appPoolIdentity}:(OI)(CI)M" /T | Out-Host
    icacls $logsPath /grant "${appPoolIdentity}:(OI)(CI)M" /T | Out-Host
    icacls $scriptsPath /grant "${appPoolIdentity}:(OI)(CI)RX" /T | Out-Host
}

function Ensure-FirewallRule {
    param(
        [string]$RuleName,
        [int]$Port
    )

    $existing = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Host
        Write-Host "Regle pare-feu ajoutee : $RuleName" -ForegroundColor Green
    }
    else {
        Write-Host "Regle pare-feu deja presente : $RuleName" -ForegroundColor Yellow
    }
}

function Ensure-WebBinding {
    param(
        [string]$HostHeader,
        [int]$Port
    )

    $expected = "*:${Port}:${HostHeader}"

    Get-Website | ForEach-Object {
        $currentSiteName = $_.Name
        $wrongBinding = Get-WebBinding -Name $currentSiteName |
            Where-Object {
                $_.protocol -eq "http" `
                -and $_.bindingInformation -eq $expected `
                -and $currentSiteName -ne $SiteName
            }

        if ($wrongBinding) {
            Remove-WebBinding -Name $currentSiteName -Protocol "http" -Port $Port -HostHeader $HostHeader
            Write-Host "Binding supprime du mauvais site $currentSiteName : $expected" -ForegroundColor Yellow
        }
    }

    $existsOnTargetSite = Get-WebBinding -Name $SiteName |
        Where-Object {
            $_.protocol -eq "http" `
            -and $_.bindingInformation -eq $expected
        }

    if (-not $existsOnTargetSite) {
        New-WebBinding -Name $SiteName -Protocol "http" -Port $Port -IPAddress "*" -HostHeader $HostHeader
        Write-Host "Binding ajoute sur $SiteName : $expected" -ForegroundColor Green
    }
    else {
        Write-Host "Binding deja present sur $SiteName : $expected" -ForegroundColor Yellow
    }
}

function Ensure-FinalBindings {
    Write-Step "Configuration bindings IIS finaux"

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if (-not $site) {
        throw "Site IIS introuvable : $SiteName"
    }

    Ensure-WebBinding -HostHeader $ExpeditionDns -Port $ShortWebPort
    Ensure-WebBinding -HostHeader $AdministrationDns -Port $ShortWebPort
    Ensure-WebBinding -HostHeader $LocalLockHost -Port $ShortWebPort

    Ensure-FirewallRule -RuleName "ServeWebEXPE HTTP 80" -Port $ShortWebPort
}

function Remove-ObsoletePort5100 {
    Write-Step "Suppression des restes du port 5100"

    $obsoleteBindings = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue |
        Where-Object { $_.protocol -eq "http" -and $_.bindingInformation -like "*:5100:*" }

    foreach ($binding in $obsoleteBindings) {
        $parts = $binding.bindingInformation.Split(":")
        $hostHeader = if ($parts.Count -ge 3) { $parts[2] } else { "" }
        Remove-WebBinding -Name $SiteName -Protocol "http" -Port 5100 -HostHeader $hostHeader
        Write-Host "Binding obsolète supprimé : $($binding.bindingInformation)" -ForegroundColor Yellow
    }

    $rules = Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*5100*" -or $_.DisplayName -like "*ServeWebEXPE HTTP 5100*" }

    foreach ($rule in $rules) {
        Remove-NetFirewallRule -Name $rule.Name
        Write-Host "Règle pare-feu 5100 supprimée : $($rule.DisplayName)" -ForegroundColor Yellow
    }
}

function Ensure-DefaultWebSiteStopped {
    $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($defaultSite -and $defaultSite.State -eq "Started") {
        Write-Host "Arrêt du Default Web Site pour éviter les réponses IIS par défaut." -ForegroundColor Yellow
        Stop-Website -Name "Default Web Site"
    }
}

function Restart-IisSite {
    Write-Step "Redemarrage IIS"

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if (-not $site) {
        throw "Site IIS introuvable : $SiteName"
    }

    $appPoolState = (Get-WebAppPoolState -Name $AppPoolName -ErrorAction Stop).Value

    if ($site.State -eq "Started") {
        Stop-Website -Name $SiteName
    }

    if ($appPoolState -eq "Started") {
        Stop-WebAppPool -Name $AppPoolName
    }

    Start-Sleep -Seconds 2

    if ((Get-WebAppPoolState -Name $AppPoolName).Value -ne "Started") {
        Start-WebAppPool -Name $AppPoolName
    }

    if ((Get-Website -Name $SiteName).State -ne "Started") {
        Start-Website -Name $SiteName
    }

    Start-Sleep -Seconds 5
}

function Invoke-HttpTest {
    param(
        [string]$Url,
        [int[]]$ExpectedStatusCodes
    )

    Write-Host ""
    Write-Host "Test HTTP : $Url" -ForegroundColor Yellow

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 20 -ErrorAction Stop
        $code = [int]$response.StatusCode
        $location = $response.Headers["Location"]

        if ($ExpectedStatusCodes -contains $code) {
            Write-Host "[OK] Code=$code Location=$location" -ForegroundColor Green
        }
        else {
            throw "Code HTTP inattendu : $code. Attendu : $($ExpectedStatusCodes -join ', ')"
        }
    }
    catch {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
            $location = $_.Exception.Response.Headers["Location"]

            if ($ExpectedStatusCodes -contains $code) {
                Write-Host "[OK] Code=$code Location=$location" -ForegroundColor Green
                return
            }

            throw "Code HTTP inattendu : $code. Location=$location. Attendu : $($ExpectedStatusCodes -join ', ')"
        }

        throw
    }
}

function Test-Deployment {
    Write-Step "Tests de verification"

    Get-Website -Name $SiteName | Format-Table -AutoSize
    Get-WebAppPoolState -Name $AppPoolName | Format-Table -AutoSize

    Write-Host ""
    Write-Host "--- Bindings IIS ---" -ForegroundColor Yellow
    Get-Website | ForEach-Object {
        $currentSiteName = $_.Name
        Get-WebBinding -Name $currentSiteName | Select-Object `
            @{Name="Site";Expression={$currentSiteName}},
            protocol,
            bindingInformation
    } | Format-Table -AutoSize

    Write-Host ""
    Write-Host "--- Tests finaux ---" -ForegroundColor Yellow
    Invoke-HttpTest -Url $ApiHealthUrl -ExpectedStatusCodes @(200)
    Invoke-HttpTest -Url "http://${ExpeditionDns}" -ExpectedStatusCodes @(200)
    Invoke-HttpTest -Url "http://${AdministrationDns}" -ExpectedStatusCodes @(200)
    Invoke-HttpTest -Url "http://${AdministrationDns}/expedition" -ExpectedStatusCodes @(302)
    Invoke-HttpTest -Url "http://${ExpeditionDns}/administration" -ExpectedStatusCodes @(302)
    Invoke-HttpTest -Url "http://${LocalLockHost}/preparations/status" -ExpectedStatusCodes @(200)
}

Write-Step "Mise a jour SERVWEB IIS"
Write-Host "DNS Expedition final      : http://${ExpeditionDns}"
Write-Host "DNS Administration final  : http://${AdministrationDns}"
Write-Host "Endpoint local verrouillage: http://${LocalLockHost}/verrouillage/executer"
Write-Host "API centrale             : $ApiBaseUrl"
Write-Host "Depot Git                : $SourcePath"
Write-Host "Dossier deploy           : $DeployPath"
Write-Host "Environnement ASP        : $AspNetCoreEnvironment"

Import-IisModuleOrStop
Assert-PathExists $DeployPath "Dossier de deploiement introuvable. Lance d'abord setup-servweb-iis.ps1"

if (-not (Get-Website -Name $SiteName -ErrorAction SilentlyContinue)) {
    throw "Site IIS introuvable : $SiteName. Lance d'abord setup-servweb-iis.ps1"
}

[Environment]::SetEnvironmentVariable("ExpeditionApi__BaseUrl", $ApiBaseUrl, "Machine")
$env:ExpeditionApi__BaseUrl = $ApiBaseUrl

Publish-Application

$site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
if ($site -and $site.State -eq "Started") {
    Stop-Website -Name $SiteName
}

$appPoolState = (Get-WebAppPoolState -Name $AppPoolName -ErrorAction Stop).Value
if ($appPoolState -eq "Started") {
    Stop-WebAppPool -Name $AppPoolName
}

Start-Sleep -Seconds 2

Backup-CurrentDeployment
Deploy-PublishedFiles
Ensure-ScheduledLockScript
Ensure-WebConfigEnvironment -WebConfigPath (Join-Path $DeployPath "web.config")
Grant-AppPoolPermissions
Ensure-FinalBindings
Remove-ObsoletePort5100
Ensure-DefaultWebSiteStopped
Restart-IisSite
Test-Deployment

Write-Step "Mise a jour terminee"
Write-Host "URL Expedition finale        : http://${ExpeditionDns}" -ForegroundColor Green
Write-Host "URL Administration finale    : http://${AdministrationDns}" -ForegroundColor Green
Write-Host "Endpoint verrouillage local  : http://${LocalLockHost}/verrouillage/executer" -ForegroundColor Green
Write-Host "API centrale DNS             : $ApiBaseUrl" -ForegroundColor Green

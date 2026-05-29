#requires -RunAsAdministrator
<#
CONFIGURATION IIS INITIALE - SERVWEB - ETAT FINAL DNS NETTOYE

Ce script sert à reconstruire proprement le site SERVEXPE avec l'état final :
- port utilisateur 80 uniquement ;
- host headers expedition.sli.local et admin.sli.local ;
- host header localhost pour la tâche Windows de verrouillage ;
- aucun port 5100.
#>

$ErrorActionPreference = "Stop"

$SiteName = "MobileSLI.Expedition.Web"
$AppPoolName = "MobileSLI.Expedition.Web"
$SourcePath = "C:\Sources\servewebEXPE"
$ProjectPath = ".\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj"
$PublishPath = "C:\Publish\MobileSLI.Expedition.Web"
$DeployPath = "C:\Services\MobileSLI.Expedition.Web"
$BackupRoot = "C:\Backups\MobileSLI.Expedition.Web"

$WebPort = 80
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
    param([string]$Path, [string]$Message)
    if (-not (Test-Path $Path)) {
        throw "$Message : $Path"
    }
}

function Enable-IisFeatures {
    Write-Step "Activation IIS et outils de scripting"

    if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
        Install-WindowsFeature Web-Server, Web-Mgmt-Console, Web-Scripting-Tools, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Http-Logging, Web-Filtering -IncludeManagementTools | Out-Host
    }
    else {
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
        throw "Module WebAdministration indisponible : $($_.Exception.Message)"
    }

    if (-not (Get-Command Get-Website -ErrorAction SilentlyContinue)) {
        throw "Get-Website indisponible."
    }
}

function Ensure-HostingBundle {
    Write-Step "Verification ASP.NET Core Hosting Bundle"

    $module = Get-WebGlobalModule | Where-Object { $_.Name -eq "AspNetCoreModuleV2" }
    if ($module) {
        Write-Host "AspNetCoreModuleV2 OK." -ForegroundColor Green
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "Hosting Bundle absent et winget indisponible. Installer manuellement le Hosting Bundle ASP.NET Core."
    }

    winget install --id Microsoft.DotNet.HostingBundle.8 -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "Installation du Hosting Bundle .NET 8 echouee."
    }

    & "$env:SystemRoot\System32\iisreset.exe" /restart | Out-Host
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

    Write-Host "Script verrouillage deploye : $targetScript" -ForegroundColor Green
}

function Grant-AppPoolPermissions {
    Write-Step "Droits AppPool sur data, logs et scripts"

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
    Write-Step "Configuration pare-feu Windows port 80"

    $ruleName = "ServeWebEXPE HTTP 80"
    $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

    if (-not $existing) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $WebPort -Action Allow | Out-Host
        Write-Host "Règle pare-feu ajoutée : $ruleName" -ForegroundColor Green
    }
    else {
        Write-Host "Règle pare-feu déjà présente : $ruleName" -ForegroundColor Yellow
    }
}

function Ensure-WebBinding {
    param(
        [string]$HostHeader
    )

    $expected = "*:${WebPort}:${HostHeader}"

    Get-Website | ForEach-Object {
        $currentSiteName = $_.Name
        $wrongBinding = Get-WebBinding -Name $currentSiteName |
            Where-Object {
                $_.protocol -eq "http" `
                -and $_.bindingInformation -eq $expected `
                -and $currentSiteName -ne $SiteName
            }

        if ($wrongBinding) {
            Remove-WebBinding -Name $currentSiteName -Protocol "http" -Port $WebPort -HostHeader $HostHeader
            Write-Host "Binding supprimé du mauvais site $currentSiteName : $expected" -ForegroundColor Yellow
        }
    }

    $exists = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue |
        Where-Object {
            $_.protocol -eq "http" `
            -and $_.bindingInformation -eq $expected
        }

    if (-not $exists) {
        New-WebBinding -Name $SiteName -Protocol "http" -Port $WebPort -IPAddress "*" -HostHeader $HostHeader
        Write-Host "Binding ajouté : $expected" -ForegroundColor Green
    }
    else {
        Write-Host "Binding déjà présent : $expected" -ForegroundColor Yellow
    }
}

function Ensure-IisSite {
    Write-Step "Configuration AppPool et site IIS final"

    if (-not (Test-Path "IIS:\AppPools\$AppPoolName")) {
        New-WebAppPool -Name $AppPoolName | Out-Null
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
            -HostHeader $ExpeditionDns `
            -ApplicationPool $AppPoolName | Out-Null
    }
    else {
        Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath
    }

    Ensure-WebBinding -HostHeader $ExpeditionDns
    Ensure-WebBinding -HostHeader $AdministrationDns
    Ensure-WebBinding -HostHeader $LocalLockHost

    $obsoleteBindings = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue |
        Where-Object { $_.protocol -eq "http" -and $_.bindingInformation -like "*:5100:*" }

    foreach ($binding in $obsoleteBindings) {
        $parts = $binding.bindingInformation.Split(":")
        $hostHeader = if ($parts.Count -ge 3) { $parts[2] } else { "" }
        Remove-WebBinding -Name $SiteName -Protocol "http" -Port 5100 -HostHeader $hostHeader
        Write-Host "Binding obsolète supprimé : $($binding.bindingInformation)" -ForegroundColor Yellow
    }

    $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($defaultSite -and $defaultSite.State -eq "Started") {
        Stop-Website -Name "Default Web Site"
        Write-Host "Default Web Site arrêté." -ForegroundColor Yellow
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

    Invoke-HttpTest -Url $ApiHealthUrl -ExpectedStatusCodes @(200)
    Invoke-HttpTest -Url "http://${ExpeditionDns}" -ExpectedStatusCodes @(200)
    Invoke-HttpTest -Url "http://${AdministrationDns}" -ExpectedStatusCodes @(200)
    Invoke-HttpTest -Url "http://${AdministrationDns}/expedition" -ExpectedStatusCodes @(302)
    Invoke-HttpTest -Url "http://${ExpeditionDns}/administration" -ExpectedStatusCodes @(302)
    Invoke-HttpTest -Url "http://${LocalLockHost}/preparations/status" -ExpectedStatusCodes @(200)
}

Write-Step "Configuration IIS initiale SERVWEB"
Write-Host "DNS Expedition      : http://${ExpeditionDns}"
Write-Host "DNS Administration  : http://${AdministrationDns}"
Write-Host "Verrouillage local  : http://${LocalLockHost}/verrouillage/executer"
Write-Host "API centrale        : $ApiBaseUrl"
Write-Host "Depot Git           : $SourcePath"
Write-Host "Dossier deploy      : $DeployPath"
Write-Host "Environnement ASP   : $AspNetCoreEnvironment"

Enable-IisFeatures
Import-IisModuleOrStop
Ensure-HostingBundle

New-Item -ItemType Directory -Path $PublishPath -Force | Out-Null
New-Item -ItemType Directory -Path $DeployPath -Force | Out-Null
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DeployPath "data") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DeployPath "logs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DeployPath "scripts") -Force | Out-Null

[Environment]::SetEnvironmentVariable("ExpeditionApi__BaseUrl", $ApiBaseUrl, "Machine")
$env:ExpeditionApi__BaseUrl = $ApiBaseUrl

Publish-Application
Deploy-PublishedFiles
Ensure-ScheduledLockScript
Ensure-WebConfigEnvironment -WebConfigPath (Join-Path $DeployPath "web.config")
Ensure-IisSite
Grant-AppPoolPermissions
Ensure-FirewallRule
Restart-IisSite
Test-Deployment

Write-Step "Configuration terminee"
Write-Host "URL Expedition finale      : http://${ExpeditionDns}" -ForegroundColor Green
Write-Host "URL Administration finale  : http://${AdministrationDns}" -ForegroundColor Green
Write-Host "Endpoint verrouillage local: http://${LocalLockHost}/verrouillage/executer" -ForegroundColor Green
Write-Host "API centrale DNS           : $ApiBaseUrl" -ForegroundColor Green

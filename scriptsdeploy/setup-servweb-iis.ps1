#requires -RunAsAdministrator
<#
CONFIGURATION IIS INITIALE - SERVWEB
Version finale DNS : aucun appel applicatif vers l'API par adresse IP.
#>

$ErrorActionPreference = "Stop"

$SiteName = "MobileSLI.Expedition.Web"
$AppPoolName = "MobileSLI.Expedition.Web"
$SourcePath = "C:\Sources\servewebEXPE"
$ProjectPath = ".\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj"
$PublishPath = "C:\Publish\MobileSLI.Expedition.Web"
$DeployPath = "C:\Services\MobileSLI.Expedition.Web"
$BackupRoot = "C:\Backups\MobileSLI.Expedition.Web"
$WebPort = 5100
$ServwebDns = "SRVINTRAWEB1.SLI.local"
$ExpeditionDns = "expedition.sli.local"
$AdministrationDns = "admin.sli.local"
$ApiDns = "SRVAPI1.SLI.local"
$ApiBaseUrl = "http://${ApiDns}:5000/"
$ApiHealthUrl = "http://${ApiDns}:5000/api/health"
$AspNetCoreEnvironment = "Development"

function Write-Step { param([string]$Message) Write-Host ""; Write-Host "=== $Message ===" -ForegroundColor Cyan }
function Assert-PathExists { param([string]$Path,[string]$Message) if (-not (Test-Path $Path)) { throw "$Message : $Path" } }
function Import-IisModuleOrStop {
    Write-Step "Chargement du module WebAdministration"
    try { Import-Module WebAdministration -ErrorAction Stop } catch { throw "Module WebAdministration indisponible : $($_.Exception.Message)" }
    if (-not (Get-Command Get-Website -ErrorAction SilentlyContinue)) { throw "Get-Website indisponible." }
}
function Stop-PortProcessIfNeeded { param([int]$Port)
    Write-Step "Controle du port $Port"
    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    foreach ($listener in $listeners) {
        $pidToStop = $listener.OwningProcess
        if ($pidToStop -eq 0) { continue }
        $proc = Get-Process -Id $pidToStop -ErrorAction SilentlyContinue
        if (-not $proc) { continue }
        if ($pidToStop -eq 4 -or $proc.ProcessName -eq "System") { Write-Host "Port $Port possede par HTTP.sys / IIS : normal." -ForegroundColor Yellow; continue }
        if ($proc.ProcessName -eq "w3wp") { Write-Host "Port $Port utilise par IIS worker w3wp : gere par IIS." -ForegroundColor Yellow; continue }
        Write-Host "Processus non-IIS detecte sur le port $Port : PID $pidToStop ($($proc.ProcessName)). Arret." -ForegroundColor Yellow
        Stop-Process -Id $pidToStop -Force
        Start-Sleep -Seconds 2
    }
}
function Set-WebConfigEnvironmentVariable { param([xml]$Document,[System.Xml.XmlElement]$EnvironmentVariablesNode,[string]$Name,[string]$Value)
    $existing = $EnvironmentVariablesNode.SelectSingleNode("environmentVariable[@name='$Name']")
    if ($existing) { $existing.SetAttribute("value", $Value) }
    else { $newNode = $Document.CreateElement("environmentVariable"); $newNode.SetAttribute("name", $Name); $newNode.SetAttribute("value", $Value); $EnvironmentVariablesNode.AppendChild($newNode) | Out-Null }
}
function Ensure-WebConfigEnvironment { param([string]$WebConfigPath)
    Write-Step "Configuration web.config"
    Assert-PathExists $WebConfigPath "web.config introuvable"
    [xml]$webConfig = Get-Content $WebConfigPath
    $systemWebServer = $webConfig.configuration.'system.webServer'
    if (-not $systemWebServer -and $webConfig.configuration.location) { $systemWebServer = $webConfig.configuration.location.'system.webServer' }
    if (-not $systemWebServer) { throw "web.config invalide : section system.webServer introuvable." }
    $aspNetCoreNode = $systemWebServer.aspNetCore
    if (-not $aspNetCoreNode) { throw "web.config invalide : noeud aspNetCore introuvable." }
    $environmentVariables = $aspNetCoreNode.environmentVariables
    if (-not $environmentVariables) { $environmentVariables = $webConfig.CreateElement("environmentVariables"); $aspNetCoreNode.AppendChild($environmentVariables) | Out-Null }
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
    if ($LASTEXITCODE -ne 0) { throw "dotnet restore a echoue." }
    dotnet build $ProjectPath -c Release --no-restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet build a echoue." }
    Remove-Item $PublishPath -Recurse -Force -ErrorAction SilentlyContinue
    dotnet publish $ProjectPath -c Release -o $PublishPath --no-build
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish a echoue." }
}
function Backup-CurrentDeployment {
    Write-Step "Sauvegarde version actuelle"
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $BackupRoot $timestamp
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    robocopy $DeployPath $backupPath /MIR /XD data logs /XF *.log
    if ($LASTEXITCODE -gt 7) { throw "Sauvegarde robocopy echouee avec le code $LASTEXITCODE." }
}
function Deploy-PublishedFiles {
    Write-Step "Copie nouvelle version"
    robocopy $PublishPath $DeployPath /MIR /XD data logs /XF *.log
    if ($LASTEXITCODE -gt 7) { throw "Deploiement robocopy echoue avec le code $LASTEXITCODE." }
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
    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if (-not $site) { throw "Site IIS introuvable : $SiteName" }
    $appPoolState = (Get-WebAppPoolState -Name $AppPoolName -ErrorAction Stop).Value
    if ($site.State -eq "Started") { Stop-Website -Name $SiteName }
    if ($appPoolState -eq "Started") { Stop-WebAppPool -Name $AppPoolName }
    Start-Sleep -Seconds 2
    if ((Get-WebAppPoolState -Name $AppPoolName).Value -ne "Started") { Start-WebAppPool -Name $AppPoolName }
    if ((Get-Website -Name $SiteName).State -ne "Started") { Start-Website -Name $SiteName }
    Start-Sleep -Seconds 5
}
function Test-Deployment {
    Write-Step "Tests de verification"
    Get-Website -Name $SiteName | Format-Table -AutoSize
    Get-WebAppPoolState -Name $AppPoolName | Format-Table -AutoSize
    curl.exe -i $ApiHealthUrl
    curl.exe -i "http://localhost:$WebPort"
    curl.exe -i "http://${ServwebDns}:$WebPort/expedition"
    curl.exe -i "http://${ExpeditionDns}:$WebPort/expedition"
    curl.exe -i "http://${AdministrationDns}:$WebPort/administration"
}

function Enable-IisFeatures {
    Write-Step "Activation IIS et outils de scripting"
    if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
        Install-WindowsFeature Web-Server, Web-Mgmt-Console, Web-Scripting-Tools, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Http-Logging, Web-Filtering -IncludeManagementTools | Out-Host
    }
    else {
        $features = @("IIS-WebServerRole", "IIS-WebServer", "IIS-ManagementConsole", "IIS-ManagementScriptingTools", "IIS-StaticContent", "IIS-DefaultDocument", "IIS-HttpErrors", "IIS-HttpLogging", "IIS-RequestFiltering")
        foreach ($feature in $features) { Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Host }
    }
}
function Ensure-HostingBundle {
    Write-Step "Verification ASP.NET Core Hosting Bundle"
    $module = Get-WebGlobalModule | Where-Object { $_.Name -eq "AspNetCoreModuleV2" }
    if ($module) { Write-Host "AspNetCoreModuleV2 OK." -ForegroundColor Green; return }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "Hosting Bundle absent et winget indisponible. Installer manuellement le Hosting Bundle ASP.NET Core." }
    winget install --id Microsoft.DotNet.HostingBundle.8 -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "Installation du Hosting Bundle .NET 8 echouee." }
    & "$env:SystemRoot\System32\iisreset.exe" /restart | Out-Host
}
function Ensure-FirewallRule {
    Write-Step "Configuration pare-feu Windows"
    $ruleName = "ServeWebEXPE HTTP 5100"
    $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if (-not $existing) { New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $WebPort -Action Allow | Out-Host }
}
function Ensure-IisSite {
    Write-Step "Configuration AppPool et site IIS"
    if (-not (Test-Path "IIS:\AppPools\$AppPoolName")) { New-WebAppPool -Name $AppPoolName | Out-Null }
    Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name managedRuntimeVersion -Value ""
    Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name startMode -Value "AlwaysRunning"
    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if (-not $site) { New-Website -Name $SiteName -PhysicalPath $DeployPath -Port $WebPort -IPAddress "*" -HostHeader "" -ApplicationPool $AppPoolName | Out-Null }
    else { Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath }
}

Write-Step "Configuration IIS initiale SERVWEB"
Write-Host "DNS SERVWEB        : $ServwebDns"
Write-Host "DNS Expedition     : $ExpeditionDns"
Write-Host "DNS Administration : $AdministrationDns"
Write-Host "Port web SERVWEB   : $WebPort"
Write-Host "API centrale       : $ApiBaseUrl"
Write-Host "Depot Git          : $SourcePath"
Write-Host "Dossier deploy     : $DeployPath"
Write-Host "Environnement ASP  : $AspNetCoreEnvironment"
Enable-IisFeatures
Import-IisModuleOrStop
Ensure-HostingBundle
New-Item -ItemType Directory -Path $PublishPath -Force | Out-Null
New-Item -ItemType Directory -Path $DeployPath -Force | Out-Null
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DeployPath "data") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DeployPath "logs") -Force | Out-Null
[Environment]::SetEnvironmentVariable("ExpeditionApi__BaseUrl", $ApiBaseUrl, "Machine")
$env:ExpeditionApi__BaseUrl = $ApiBaseUrl
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
Write-Host "URL locale          : http://localhost:$WebPort" -ForegroundColor Green
Write-Host "URL serveur DNS     : http://${ServwebDns}:$WebPort" -ForegroundColor Green
Write-Host "URL Expedition DNS  : http://${ExpeditionDns}:$WebPort/expedition" -ForegroundColor Green
Write-Host "URL Admin DNS       : http://${AdministrationDns}:$WebPort/administration" -ForegroundColor Green
Write-Host "API centrale DNS    : $ApiBaseUrl" -ForegroundColor Green

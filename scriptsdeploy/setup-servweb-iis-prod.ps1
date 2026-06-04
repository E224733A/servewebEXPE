$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================================
# Installation / publication SERVWEB IIS - PRODUCTION
# ============================================================
# Ce script publie directement depuis les sources locales.
# Pour les mises a jour courantes, preferer update-servweb-iis.ps1
# qui deploie l'artefact Git deja publie.
# ============================================================

$RepoRoot = "C:\Sources\servewebEXPE"
$ProjectDir = Join-Path $RepoRoot "src\MobileSLI.Expedition.Web"
$ProjectPath = Join-Path $ProjectDir "MobileSLI.Expedition.Web.csproj"
$PublishDir = "C:\Publish\MobileSLI.Expedition.Web"
$DeployDir = "C:\Services\MobileSLI.Expedition.Web"
$BackupRoot = "C:\Backups\MobileSLI.Expedition.Web"

$SiteName = "MobileSLI.Expedition.Web"
$AppPoolName = "MobileSLI.Expedition.Web"

$ExpeditionUrl = "http://expedition.sli.local"
$AdministrationUrl = "http://admin.sli.local"
$LocalVerrouillageUrl = "http://localhost/verrouillage/executer"
$ApiBaseUrl = "http://api.mobilesli.intra:5000/"
$AspNetEnvironment = "Production"

$FirewallRuleName = "ServeWebEXPE HTTP 80"

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Title
    Write-Host "============================================================"
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$ErrorMessage
    )

    & $FilePath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Invoke-RobocopyChecked {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    robocopy $Source $Destination @Arguments

    $code = $LASTEXITCODE

    if ($code -gt 7) {
        throw "Robocopy a echoue avec le code $code."
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Stop-BuildProcesses {
    Write-Host "Arret des serveurs de build dotnet/Roslyn si presents."

    Get-Process VBCSCompiler -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process MSBuild -ErrorAction SilentlyContinue | Stop-Process -Force

    try {
        dotnet build-server shutdown | Out-Host
    }
    catch {
        Write-Host "Impossible d'arreter dotnet build-server, poursuite du script."
    }
}

function Stop-IisApp {
    Import-Module WebAdministration

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if ($null -ne $site -and $site.State -ne "Stopped") {
        Stop-Website -Name $SiteName
    }

    $appPoolState = $null
    try {
        $appPoolState = (Get-WebAppPoolState -Name $AppPoolName -ErrorAction Stop).Value
    }
    catch {
        $appPoolState = $null
    }

    if ($null -ne $appPoolState -and $appPoolState -ne "Stopped") {
        Stop-WebAppPool -Name $AppPoolName
    }

    Start-Sleep -Seconds 3

    $workerProcesses = Get-CimInstance Win32_Process -Filter "name = 'w3wp.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$AppPoolName*" }

    foreach ($workerProcess in $workerProcesses) {
        Write-Host "Arret du worker IIS restant PID=$($workerProcess.ProcessId)"
        Stop-Process -Id $workerProcess.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Start-IisApp {
    Import-Module WebAdministration

    $appPool = Get-Item "IIS:\AppPools\$AppPoolName" -ErrorAction SilentlyContinue
    if ($null -eq $appPool) {
        throw "AppPool introuvable : $AppPoolName"
    }

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if ($null -eq $site) {
        throw "Site IIS introuvable : $SiteName"
    }

    $appPoolState = (Get-WebAppPoolState -Name $AppPoolName).Value
    if ($appPoolState -ne "Started") {
        Start-WebAppPool -Name $AppPoolName
    }

    if ($site.State -ne "Started") {
        Start-Website -Name $SiteName
    }
}

function Set-WebConfigEnvironmentVariable {
    param(
        [Parameter(Mandatory = $true)][xml]$WebConfig,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$AspNetCoreNode,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $environmentVariablesNode = $AspNetCoreNode.environmentVariables

    if ($null -eq $environmentVariablesNode) {
        $environmentVariablesNode = $WebConfig.CreateElement("environmentVariables")
        [void]$AspNetCoreNode.AppendChild($environmentVariablesNode)
    }

    $existingNode = $environmentVariablesNode.environmentVariable |
        Where-Object { $_.name -eq $Name } |
        Select-Object -First 1

    if ($null -eq $existingNode) {
        $existingNode = $WebConfig.CreateElement("environmentVariable")

        $nameAttribute = $WebConfig.CreateAttribute("name")
        $nameAttribute.Value = $Name
        [void]$existingNode.Attributes.Append($nameAttribute)

        $valueAttribute = $WebConfig.CreateAttribute("value")
        $valueAttribute.Value = $Value
        [void]$existingNode.Attributes.Append($valueAttribute)

        [void]$environmentVariablesNode.AppendChild($existingNode)
    }
    else {
        $existingNode.value = $Value
    }
}

function Configure-WebConfig {
    $webConfigPath = Join-Path $DeployDir "web.config"

    if (-not (Test-Path $webConfigPath)) {
        throw "web.config introuvable : $webConfigPath"
    }

    [xml]$webConfig = Get-Content $webConfigPath -Raw
    $aspNetCoreNode = $webConfig.configuration.'system.webServer'.aspNetCore

    if ($null -eq $aspNetCoreNode) {
        throw "Noeud aspNetCore introuvable dans web.config."
    }

    Set-WebConfigEnvironmentVariable `
        -WebConfig $webConfig `
        -AspNetCoreNode $aspNetCoreNode `
        -Name "ASPNETCORE_ENVIRONMENT" `
        -Value $AspNetEnvironment

    Set-WebConfigEnvironmentVariable `
        -WebConfig $webConfig `
        -AspNetCoreNode $aspNetCoreNode `
        -Name "ExpeditionApi__BaseUrl" `
        -Value $ApiBaseUrl

    $webConfig.Save($webConfigPath)

    Write-Host "ASPNETCORE_ENVIRONMENT = $AspNetEnvironment"
    Write-Host "ExpeditionApi__BaseUrl = $ApiBaseUrl"
}

function Grant-AppPoolRights {
    $identity = "IIS AppPool\$AppPoolName"

    $directories = @(
        (Join-Path $DeployDir "data"),
        (Join-Path $DeployDir "logs"),
        (Join-Path $DeployDir "scripts")
    )

    foreach ($directory in $directories) {
        Ensure-Directory -Path $directory
        icacls $directory /grant "${identity}:(OI)(CI)(M)" /T | Out-Host
    }
}

function Ensure-HttpBinding {
    param([Parameter(Mandatory = $true)][string]$HostHeader)

    Import-Module WebAdministration

    $bindingInformation = "*:80:$HostHeader"

    $existingBinding = Get-WebBinding -Name $SiteName -Protocol "http" -ErrorAction SilentlyContinue |
        Where-Object { $_.bindingInformation -eq $bindingInformation } |
        Select-Object -First 1

    if ($null -eq $existingBinding) {
        New-WebBinding -Name $SiteName -Protocol "http" -IPAddress "*" -Port 80 -HostHeader $HostHeader
        Write-Host "Binding ajoute sur $SiteName : $bindingInformation"
    }
    else {
        Write-Host "Binding deja present sur $SiteName : $bindingInformation"
    }
}

function Ensure-FirewallRule {
    $existingRule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue

    if ($null -eq $existingRule) {
        New-NetFirewallRule `
            -DisplayName $FirewallRuleName `
            -Direction Inbound `
            -Action Allow `
            -Protocol TCP `
            -LocalPort 80 | Out-Null

        Write-Host "Regle pare-feu ajoutee : $FirewallRuleName"
    }
    else {
        Write-Host "Regle pare-feu deja presente : $FirewallRuleName"
    }
}

function Remove-Port5100Bindings {
    Import-Module WebAdministration

    $bindings5100 = Get-WebBinding -Name $SiteName -ErrorAction SilentlyContinue |
        Where-Object { $_.bindingInformation -like "*:5100:*" }

    foreach ($binding in $bindings5100) {
        Remove-WebBinding `
            -Name $SiteName `
            -Protocol $binding.protocol `
            -BindingInformation $binding.bindingInformation

        Write-Host "Binding port 5100 supprime : $($binding.bindingInformation)"
    }

    $oldFirewallRules = Get-NetFirewallRule -DisplayName "ServeWebEXPE HTTP 5100" -ErrorAction SilentlyContinue
    foreach ($rule in $oldFirewallRules) {
        Remove-NetFirewallRule -Name $rule.Name
        Write-Host "Ancienne regle pare-feu 5100 supprimee : $($rule.DisplayName)"
    }
}

function Copy-PlannedLockScript {
    $sourceScript = Join-Path $RepoRoot "scriptsdeploy\run-verrouillage.ps1"
    $destinationDirectory = Join-Path $DeployDir "scripts"
    $destinationScript = Join-Path $destinationDirectory "run-verrouillage.ps1"

    Ensure-Directory -Path $destinationDirectory

    if (Test-Path $sourceScript) {
        Copy-Item -Path $sourceScript -Destination $destinationScript -Force
        Write-Host "Script verrouillage deploye : $destinationScript"
    }
    else {
        Write-Host "Script source introuvable, conservation du script deja deploye si present : $sourceScript"
    }
}

function Test-HttpEndpoint {
    param([Parameter(Mandatory = $true)][string]$Url)

    try {
        $response = Invoke-WebRequest `
            -Uri $Url `
            -UseBasicParsing `
            -MaximumRedirection 0 `
            -TimeoutSec 10 `
            -ErrorAction Stop

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

Write-Section "Mise a jour SERVWEB IIS - PRODUCTION"
Write-Host "DNS Expedition final       : $ExpeditionUrl"
Write-Host "DNS Administration final   : $AdministrationUrl"
Write-Host "Endpoint local verrouillage: $LocalVerrouillageUrl"
Write-Host "API centrale              : $ApiBaseUrl"
Write-Host "Depot Git                 : $RepoRoot"
Write-Host "Dossier deploy            : $DeployDir"
Write-Host "Environnement ASP         : $AspNetEnvironment"

Write-Section "Chargement du module WebAdministration"
Import-Module WebAdministration

Write-Section "Mise a jour Git et publication Release"
Set-Location $RepoRoot

git status
$gitChanges = git status --porcelain

if (-not [string]::IsNullOrWhiteSpace(($gitChanges -join "`n"))) {
    throw "Le depot contient des modifications locales. Commit, stash ou reset avant de deployer."
}

git pull --ff-only
if ($LASTEXITCODE -ne 0) {
    throw "git pull --ff-only a echoue."
}

Stop-BuildProcesses

Write-Host "Nettoyage bin/obj pour eviter les restes de build."
Remove-Item -Recurse -Force (Join-Path $ProjectDir "bin") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $ProjectDir "obj") -ErrorAction SilentlyContinue

Ensure-Directory -Path $PublishDir
Remove-Item -Recurse -Force $PublishDir -ErrorAction SilentlyContinue
Ensure-Directory -Path $PublishDir

$buildArguments = @(
    "build",
    $ProjectPath,
    "-c",
    "Release",
    "-m:1",
    "/nr:false",
    "-p:RunAnalyzers=false",
    "-p:RunAnalyzersDuringBuild=false",
    "-p:RunAnalyzersDuringLiveAnalysis=false",
    "-p:UseSharedCompilation=false"
)

Invoke-ExternalCommand `
    -FilePath "dotnet" `
    -Arguments $buildArguments `
    -ErrorMessage "dotnet build a echoue."

$publishArguments = @(
    "publish",
    $ProjectPath,
    "-c",
    "Release",
    "-o",
    $PublishDir,
    "-m:1",
    "/nr:false",
    "-p:RunAnalyzers=false",
    "-p:RunAnalyzersDuringBuild=false",
    "-p:RunAnalyzersDuringLiveAnalysis=false",
    "-p:UseSharedCompilation=false"
)

Invoke-ExternalCommand `
    -FilePath "dotnet" `
    -Arguments $publishArguments `
    -ErrorMessage "dotnet publish a echoue."

Write-Section "Sauvegarde version actuelle"

Ensure-Directory -Path $DeployDir
Ensure-Directory -Path $BackupRoot

$backupStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $BackupRoot $backupStamp

Invoke-RobocopyChecked `
    -Source $DeployDir `
    -Destination $backupDir `
    -Arguments @("/S", "/E", "/DCOPY:DA", "/COPY:DAT", "/PURGE", "/MIR", "/R:3", "/W:5", "/XD", "data", "logs", "/XF", "*.log")

Write-Section "Arret IIS avant copie"
Stop-IisApp

try {
    Write-Section "Copie nouvelle version"

    Invoke-RobocopyChecked `
        -Source $PublishDir `
        -Destination $DeployDir `
        -Arguments @("/S", "/E", "/DCOPY:DA", "/COPY:DAT", "/PURGE", "/MIR", "/R:3", "/W:5", "/XD", "data", "logs", "scripts", "/XF", "*.log")

    Write-Section "Copie du script de verrouillage planifie"
    Copy-PlannedLockScript

    Write-Section "Configuration web.config"
    Configure-WebConfig

    Write-Section "Droits AppPool sur data, logs et scripts"
    Grant-AppPoolRights

    Write-Section "Configuration bindings IIS finaux"
    Ensure-HttpBinding -HostHeader "expedition.sli.local"
    Ensure-HttpBinding -HostHeader "admin.sli.local"
    Ensure-HttpBinding -HostHeader "localhost"
    Ensure-FirewallRule

    Write-Section "Suppression des restes du port 5100"
    Remove-Port5100Bindings
}
catch {
    Write-Section "Erreur pendant la copie/configuration"
    Write-Host $_.Exception.Message
    Write-Host "Tentative de redemarrage IIS avec la version disponible."
    Start-IisApp
    throw
}

Write-Section "Redemarrage IIS"
Start-IisApp

Write-Section "Tests de verification"

Get-Website -Name $SiteName
Get-WebAppPoolState -Name $AppPoolName

Write-Host ""
Write-Host "--- Bindings IIS ---"
Get-WebBinding | Select-Object @{Name = "Site"; Expression = { $_.ItemXPath -replace ".*name='([^']+)'.*", '$1' } }, protocol, bindingInformation | Format-Table -AutoSize

Write-Host ""
Write-Host "--- Tests finaux ---"

$testUrls = @(
    "http://api.mobilesli.intra:5000/api/health",
    "http://expedition.sli.local",
    "http://admin.sli.local",
    "http://admin.sli.local/expedition",
    "http://expedition.sli.local/administration",
    "http://localhost/preparations/status"
)

foreach ($url in $testUrls) {
    Write-Host ""
    Write-Host "Test HTTP : $url"
    Test-HttpEndpoint -Url $url
}

Write-Section "Mise a jour terminee"
Write-Host "URL Expedition finale        : $ExpeditionUrl"
Write-Host "URL Administration finale    : $AdministrationUrl"
Write-Host "Endpoint verrouillage local  : $LocalVerrouillageUrl"
Write-Host "API centrale DNS             : $ApiBaseUrl"

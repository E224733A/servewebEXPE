$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================================
# Mise a jour SERVWEB IIS - MobileSLI Expedition Web
# ============================================================
# Objectif :
# - Recuperer la derniere version Git.
# - Compiler/publier en Release sur SERVWEB sans analyse Roslyn complete.
# - Sauvegarder la version actuelle.
# - Deployer vers IIS.
# - Conserver data, logs et scripts.
# - Configurer web.config, bindings et pare-feu.
# - Verifier les URLs finales.
# ============================================================

$SiteName = "MobileSLI.Expedition.Web"
$AppPoolName = "MobileSLI.Expedition.Web"

$SourcePath = "C:\Sources\servewebEXPE"
$ProjectPath = ".\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj"
$ProjectDirectory = ".\src\MobileSLI.Expedition.Web"

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
$AspNetEnvironment = "Development"

$FirewallRuleName = "ServeWebEXPE HTTP 80"

function Write-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Assert-PathExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not (Test-Path $Path)) {
        throw "$Message : $Path"
    }
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Invoke-RobocopyChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage
    )

    robocopy $Source $Destination @Arguments

    $exitCode = $LASTEXITCODE

    if ($exitCode -gt 7) {
        throw "$ErrorMessage Code Robocopy=$exitCode"
    }
}

function Stop-BuildProcesses {
    Write-Host "Arret des processus de build pour liberer la memoire."

    Get-Process VBCSCompiler -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process MSBuild -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    try {
        dotnet build-server shutdown | Out-Host
    }
    catch {
        Write-Host "dotnet build-server shutdown non critique, poursuite du script."
    }
}

function Stop-IisApplication {
    Write-Step "Arret IIS avant copie"

    Import-Module WebAdministration

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if ($null -ne $site) {
        if ($site.State -ne "Stopped") {
            Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
        }
    }

    $appPool = Get-Item "IIS:\AppPools\$AppPoolName" -ErrorAction SilentlyContinue
    if ($null -ne $appPool) {
        if ($appPool.State -ne "Stopped") {
            Stop-WebAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
        }
    }

    Start-Sleep -Seconds 3

    $workerProcesses = Get-CimInstance Win32_Process -Filter "name = 'w3wp.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$AppPoolName*" }

    foreach ($workerProcess in $workerProcesses) {
        Write-Host "Worker IIS encore actif, arret force PID=$($workerProcess.ProcessId)"
        Stop-Process -Id $workerProcess.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Start-IisApplication {
    Write-Step "Redemarrage IIS"

    Import-Module WebAdministration

    $appPool = Get-Item "IIS:\AppPools\$AppPoolName" -ErrorAction SilentlyContinue
    if ($null -eq $appPool) {
        throw "AppPool introuvable : $AppPoolName"
    }

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if ($null -eq $site) {
        throw "Site IIS introuvable : $SiteName"
    }

    if ($appPool.State -ne "Started") {
        Start-WebAppPool -Name $AppPoolName
    }

    if ($site.State -ne "Started") {
        Start-Website -Name $SiteName
    }
}

function Publish-Application {
    Write-Step "Mise a jour Git et publication Release"

    Assert-PathExists $SourcePath "Dossier source introuvable"

    Set-Location $SourcePath

    git status

    $gitChanges = git status --porcelain
    if (-not [string]::IsNullOrWhiteSpace($gitChanges)) {
        throw "Le depot contient des modifications locales. Commit, stash ou reset avant de deployer."
    }

    git pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        throw "git pull --ff-only a echoue."
    }

    Stop-BuildProcesses

    Write-Host "Nettoyage bin/obj."
    Remove-Item -Recurse -Force (Join-Path $SourcePath "src\MobileSLI.Expedition.Web\bin") -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force (Join-Path $SourcePath "src\MobileSLI.Expedition.Web\obj") -ErrorAction SilentlyContinue

    Write-Host "Restauration NuGet."
    dotnet restore $ProjectPath
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet restore a echoue."
    }

    Write-Host "Build Release SERVWEB sans analyzers Roslyn complets."
    dotnet build $ProjectPath `
        -c Release `
        --no-restore `
        -m:1 `
        /nr:false `
        -p:RunAnalyzers=false `
        -p:RunAnalyzersDuringBuild=false `
        -p:RunAnalyzersDuringLiveAnalysis=false `
        -p:UseSharedCompilation=false

    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build a echoue."
    }

    Write-Host "Nettoyage dossier publish."
    Remove-Item $PublishPath -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $PublishPath | Out-Null

    Write-Host "Publish Release SERVWEB sans rebuild et sans analyzers."
    dotnet publish $ProjectPath `
        -c Release `
        -o $PublishPath `
        --no-build `
        -m:1 `
        /nr:false `
        -p:RunAnalyzers=false `
        -p:RunAnalyzersDuringBuild=false `
        -p:RunAnalyzersDuringLiveAnalysis=false `
        -p:UseSharedCompilation=false

    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish a echoue."
    }
}

function Backup-CurrentDeployment {
    Write-Step "Sauvegarde version actuelle"

    Ensure-Directory $DeployPath
    Ensure-Directory $BackupRoot

    $backupName = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $BackupRoot $backupName

    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    Invoke-RobocopyChecked `
        -Source $DeployPath `
        -Destination $backupPath `
        -Arguments @("/MIR", "/R:3", "/W:5", "/XD", "data", "logs", "/XF", "*.log") `
        -ErrorMessage "Sauvegarde robocopy echouee."
}

function Deploy-PublishedFiles {
    Write-Step "Copie nouvelle version"

    Assert-PathExists $PublishPath "Dossier publish introuvable"
    Ensure-Directory $DeployPath

    Invoke-RobocopyChecked `
        -Source $PublishPath `
        -Destination $DeployPath `
        -Arguments @("/MIR", "/R:3", "/W:5", "/XD", "data", "logs", "scripts", "/XF", "*.log") `
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

function Set-WebConfigEnvironmentVariable {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$WebConfig,

        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$AspNetCoreNode,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value
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

function Ensure-WebConfigEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WebConfigPath
    )

    Write-Step "Configuration web.config"

    if (-not (Test-Path $WebConfigPath)) {
        throw "web.config introuvable : $WebConfigPath"
    }

    [xml]$webConfig = Get-Content $WebConfigPath -Raw

    $systemWebServerNode = $webConfig.configuration.'system.webServer'
    if ($null -eq $systemWebServerNode) {
        throw "Noeud system.webServer introuvable dans web.config."
    }

    $aspNetCoreNode = $systemWebServerNode.aspNetCore
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

    $webConfig.Save($WebConfigPath)

    Write-Host "ASPNETCORE_ENVIRONMENT = $AspNetEnvironment"
    Write-Host "ExpeditionApi__BaseUrl = $ApiBaseUrl"
}

function Grant-AppPoolPermissions {
    Write-Step "Droits AppPool sur data et logs"

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
        [Parameter(Mandatory = $true)]
        [string]$HostHeader,

        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    Import-Module WebAdministration

    $expectedBinding = "*:${Port}:$HostHeader"

    $existing = Get-WebBinding -Name $SiteName -Protocol "http" -ErrorAction SilentlyContinue |
        Where-Object { $_.bindingInformation -eq $expectedBinding } |
        Select-Object -First 1

    if ($null -eq $existing) {
        New-WebBinding `
            -Name $SiteName `
            -Protocol "http" `
            -IPAddress "*" `
            -Port $Port `
            -HostHeader $HostHeader

        Write-Host "Binding ajoute sur $SiteName : $expectedBinding"
    }
    else {
        Write-Host "Binding deja present sur $SiteName : $expectedBinding"
    }
}

function Ensure-FirewallRule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName,

        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    Write-Host "Verification pare-feu via netsh : $RuleName"

    $ruleOutput = netsh advfirewall firewall show rule name="$RuleName" 2>&1
    $ruleText = $ruleOutput -join "`n"

    $ruleMissing = $false

    if ($LASTEXITCODE -ne 0) {
        $ruleMissing = $true
    }

    if ($ruleText -match "No rules match" -or
        $ruleText -match "Aucune r" -or
        $ruleText -match "Aucune regle" -or
        $ruleText -match "Aucun") {
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
        Remove-WebBinding `
            -Name $SiteName `
            -Protocol $binding.protocol `
            -BindingInformation $binding.bindingInformation

        Write-Host "Binding port 5100 supprime : $($binding.bindingInformation)"
    }

    $ruleNames = @(
        "ServeWebEXPE HTTP 5100",
        "SERVWEB HTTP 5100",
        "MobileSLI Expedition HTTP 5100"
    )

    foreach ($ruleName in $ruleNames) {
        $ruleOutput = netsh advfirewall firewall show rule name="$ruleName" 2>&1
        $ruleText = $ruleOutput -join "`n"

        $ruleExists = $true

        if ($LASTEXITCODE -ne 0) {
            $ruleExists = $false
        }

        if ($ruleText -match "No rules match" -or
            $ruleText -match "Aucune r" -or
            $ruleText -match "Aucune regle" -or
            $ruleText -match "Aucun") {
            $ruleExists = $false
        }

        if ($ruleExists) {
            netsh advfirewall firewall delete rule name="$ruleName" | Out-Host
            Write-Host "Regle pare-feu 5100 supprimee : $ruleName"
        }
    }
}

function Test-HttpEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $Url `
            -UseBasicParsing `
            -MaximumRedirection 0 `
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

function Run-FinalChecks {
    Write-Step "Tests de verification"

    Import-Module WebAdministration

    Get-Website -Name $SiteName
    Get-WebAppPoolState -Name $AppPoolName

    Write-Host ""
    Write-Host "--- Bindings IIS ---"

    Get-WebBinding -Name $SiteName |
        Select-Object protocol, bindingInformation |
        Format-Table -AutoSize

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

# ============================================================
# Execution
# ============================================================

Write-Step "Mise a jour SERVWEB IIS"
Write-Host "DNS Expedition final      : $ExpeditionUrl"
Write-Host "DNS Administration final  : $AdministrationUrl"
Write-Host "Endpoint local verrouillage: $LocalLockUrl"
Write-Host "API centrale             : $ApiBaseUrl"
Write-Host "Depot Git                : $SourcePath"
Write-Host "Dossier deploy           : $DeployPath"
Write-Host "Environnement ASP        : $AspNetEnvironment"

Write-Step "Chargement du module WebAdministration"
Import-Module WebAdministration

Set-Location $SourcePath

$env:ASPNETCORE_ENVIRONMENT = $AspNetEnvironment
$env:ExpeditionApi__BaseUrl = $ApiBaseUrl

Publish-Application

$site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
if ($site -and $site.State -eq "Started") {
    Write-Host "Site en cours d'execution avant sauvegarde : $SiteName"
}

Backup-CurrentDeployment

Stop-IisApplication

try {
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
    Write-Host "Tentative de redemarrage IIS avec la version disponible."
    Start-IisApplication
    throw
}

Start-IisApplication
Run-FinalChecks

Write-Step "Mise a jour terminee"
Write-Host "URL Expedition finale        : $ExpeditionUrl"
Write-Host "URL Administration finale    : $AdministrationUrl"
Write-Host "Endpoint verrouillage local  : $LocalLockUrl"
Write-Host "API centrale DNS             : $ApiBaseUrl"
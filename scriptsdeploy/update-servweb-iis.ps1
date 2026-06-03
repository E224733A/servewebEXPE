$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================================
# Mise a jour SERVWEB IIS depuis artefact Git
# ============================================================
# Ce script NE COMPILE PAS.
# Il recupere le ZIP publie dans Git, le dezippe et le deploie sur IIS.
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
$AspNetEnvironment = "Development"

$FirewallRuleName = "ServeWebEXPE HTTP 80"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
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

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Invoke-RobocopyChecked {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$Arguments,
        [string]$ErrorMessage
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

    Expand-Archive `
        -Path $artifactPath `
        -DestinationPath $PublishPath `
        -Force

    Assert-PathExists (Join-Path $PublishPath "MobileSLI.Expedition.Web.dll") "DLL publiee introuvable apres extraction"
    Assert-PathExists (Join-Path $PublishPath "web.config") "web.config publie introuvable apres extraction"

    $dll = Get-Item (Join-Path $PublishPath "MobileSLI.Expedition.Web.dll")
    Write-Host ""
    Write-Host "Artefact extrait vers : $PublishPath"
    Write-Host "DLL LastWriteTime     : $($dll.LastWriteTime)"
    Write-Host "DLL Taille Mo         : $([math]::Round($dll.Length / 1MB, 2))"
}

function Stop-IisApplication {
    Write-Step "Arret IIS avant copie"

    Import-Module WebAdministration

    Stop-Website $SiteName -ErrorAction SilentlyContinue
    Stop-WebAppPool $AppPoolName -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 3

    Get-CimInstance Win32_Process -Filter "name = 'w3wp.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$AppPoolName*" } |
        ForEach-Object {
            Write-Host "Worker IIS encore actif, arret force PID=$($_.ProcessId)"
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
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
        Start-WebAppPool $AppPoolName
    }

    if ($site.State -ne "Started") {
        Start-Website $SiteName
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

    Write-Host "Backup cree : $backupPath"
}

function Deploy-PublishedFiles {
    Write-Step "Copie artefact vers IIS"

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
        [xml]$WebConfig,
        [System.Xml.XmlElement]$AspNetCoreNode,
        [string]$Name,
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
    param([string]$WebConfigPath)

    Write-Step "Configuration web.config"

    if (-not (Test-Path $WebConfigPath)) {
        throw "web.config introuvable : $WebConfigPath"
    }

    [xml]$webConfig = Get-Content $WebConfigPath -Raw

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
        [string]$HostHeader,
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
        [string]$RuleName,
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
    param([string]$Url)

    try {
        $response = Invoke-WebRequest `
            -Uri $Url `
            -UseBasicParsing `
            -MaximumRedirection 0 `
            -ErrorAction SilentlyContinue

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

Write-Step "Mise a jour SERVWEB IIS depuis artefact Git"
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
Write-Host "URL Expedition finale       : $ExpeditionUrl"
Write-Host "URL Administration finale   : $AdministrationUrl"
Write-Host "Endpoint verrouillage local : $LocalLockUrl"
Write-Host "API centrale DNS            : $ApiBaseUrl"

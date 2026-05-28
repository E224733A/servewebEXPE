#requires -RunAsAdministrator
<#
MISE A JOUR SERVWEB IIS
Version finale DNS :
- aucun appel applicatif vers l'API par adresse IP ;
- URL utilisateur courte pour l'Expédition : http://expedition.sli.local ;
- URL utilisateur courte pour l'Administration : http://admin.sli.local ;
- port 5100 conservé pour diagnostic technique.
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
$ShortWebPort = 80
$ServwebDns = "SRVINTRAWEB1.SLI.local"
$ExpeditionDns = "expedition.sli.local"
$AdministrationDns = "admin.sli.local"
$ApiDns = "api.mobilesli.intra"
$ApiBaseUrl = "http://${ApiDns}:5000/"
$ApiHealthUrl = "http://${ApiDns}:5000/api/health"
$AspNetCoreEnvironment = "Development"

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
        Write-Host "Module WebAdministration indisponible. Tentative d'installation des outils IIS de scripting." -ForegroundColor Yellow

        if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
            Install-WindowsFeature Web-Scripting-Tools -IncludeManagementTools | Out-Host
        }
        elseif (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
            Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementScriptingTools -All -NoRestart | Out-Host
            Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole -All -NoRestart | Out-Host
        }
        else {
            throw "Module WebAdministration indisponible et aucune commande d'installation IIS n'est disponible. Lance ce script directement sur SERVWEB/SRVINTRAWEB1 en PowerShell administrateur. Erreur initiale : $($_.Exception.Message)"
        }

        Import-Module WebAdministration -ErrorAction Stop
    }

    if (-not (Get-Command Get-Website -ErrorAction SilentlyContinue)) {
        throw "Get-Website indisponible après chargement de WebAdministration. Vérifie que les outils IIS de scripting sont installés."
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

        if ($pidToStop -eq 4 -or $proc.ProcessName -eq "System") {
            Write-Host "Port $Port possede par HTTP.sys / IIS : normal." -ForegroundColor Yellow
            continue
        }

        if ($proc.ProcessName -eq "w3wp") {
            Write-Host "Port $Port utilise par IIS worker w3wp : gere par IIS." -ForegroundColor Yellow
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

function Ensure-WebBindingOnSite {
    param(
        [string]$TargetSiteName,
        [string]$Protocol,
        [int]$Port,
        [string]$HostHeader
    )

    $expected = "*:${Port}:${HostHeader}"

    Get-Website | ForEach-Object {
        $currentSiteName = $_.Name

        if ($currentSiteName -eq $TargetSiteName) {
            return
        }

        $wrongBindings = Get-WebBinding -Name $currentSiteName -ErrorAction SilentlyContinue |
            Where-Object {
                $_.protocol -eq $Protocol `
                    -and $_.bindingInformation -eq $expected
            }

        foreach ($wrongBinding in $wrongBindings) {
            Remove-WebBinding `
                -Name $currentSiteName `
                -Protocol $Protocol `
                -Port $Port `
                -HostHeader $HostHeader

            Write-Host "Binding supprime du mauvais site $currentSiteName : $expected" -ForegroundColor Yellow
        }
    }

    $existsOnTargetSite = Get-WebBinding -Name $TargetSiteName |
        Where-Object {
            $_.protocol -eq $Protocol `
                -and $_.bindingInformation -eq $expected
        }

    if (-not $existsOnTargetSite) {
        New-WebBinding `
            -Name $TargetSiteName `
            -Protocol $Protocol `
            -Port $Port `
            -IPAddress "*" `
            -HostHeader $HostHeader

        Write-Host "Binding ajoute sur $TargetSiteName : $expected" -ForegroundColor Green
    }
    else {
        Write-Host "Binding deja present sur $TargetSiteName : $expected" -ForegroundColor Yellow
    }
}

function Ensure-WebBindings {
    Write-Step "Configuration bindings IIS"

    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if (-not $site) {
        throw "Site IIS introuvable : $SiteName"
    }

    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath

    Ensure-WebBindingOnSite -TargetSiteName $SiteName -Protocol "http" -Port $ShortWebPort -HostHeader $ExpeditionDns
    Ensure-WebBindingOnSite -TargetSiteName $SiteName -Protocol "http" -Port $ShortWebPort -HostHeader $AdministrationDns

    $diagnosticBinding = "*:${WebPort}:"
    $hasDiagnosticBinding = Get-WebBinding -Name $SiteName |
        Where-Object {
            $_.protocol -eq "http" `
                -and $_.bindingInformation -eq $diagnosticBinding
        }

    if (-not $hasDiagnosticBinding) {
        New-WebBinding `
            -Name $SiteName `
            -Protocol "http" `
            -Port $WebPort `
            -IPAddress "*" `
            -HostHeader ""

        Write-Host "Binding diagnostic ajoute sur $SiteName : $diagnosticBinding" -ForegroundColor Green
    }
    else {
        Write-Host "Binding diagnostic deja present sur $SiteName : $diagnosticBinding" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Bindings actuels :" -ForegroundColor Cyan
    Get-Website | ForEach-Object {
        $currentSiteName = $_.Name
        Get-WebBinding -Name $currentSiteName | Select-Object `
            @{Name = "Site"; Expression = { $currentSiteName } },
            protocol,
            bindingInformation
    } | Format-Table -AutoSize
}

function Ensure-FirewallRule {
    param(
        [string]$RuleName,
        [int]$Port
    )

    $existing = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Host
        Write-Host "Regle pare-feu ajoutee : $RuleName / port $Port" -ForegroundColor Green
    }
    else {
        Write-Host "Regle pare-feu deja presente : $RuleName / port $Port" -ForegroundColor Yellow
    }
}

function Ensure-FirewallRules {
    Write-Step "Configuration pare-feu Windows"

    Ensure-FirewallRule -RuleName "ServeWebEXPE HTTP 80" -Port $ShortWebPort
    Ensure-FirewallRule -RuleName "ServeWebEXPE HTTP 5100" -Port $WebPort
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

function Test-Deployment {
    Write-Step "Tests de verification"

    Get-Website -Name $SiteName | Format-Table -AutoSize
    Get-WebAppPoolState -Name $AppPoolName | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Test API centrale" -ForegroundColor Cyan
    curl.exe -i $ApiHealthUrl

    Write-Host ""
    Write-Host "Tests Web courts" -ForegroundColor Cyan
    curl.exe -i "http://${ExpeditionDns}"
    curl.exe -i "http://${AdministrationDns}"

    Write-Host ""
    Write-Host "Tests Web avec routes explicites" -ForegroundColor Cyan
    curl.exe -i "http://${ExpeditionDns}/expedition"
    curl.exe -i "http://${AdministrationDns}/administration"

    Write-Host ""
    Write-Host "Tests anti-confusion" -ForegroundColor Cyan
    curl.exe -i "http://${AdministrationDns}/expedition"
    curl.exe -i "http://${ExpeditionDns}/administration"

    Write-Host ""
    Write-Host "Tests diagnostic port $WebPort" -ForegroundColor Cyan
    curl.exe -i "http://localhost:$WebPort/expedition"
    curl.exe -i "http://${ServwebDns}:$WebPort/expedition"
}

Write-Step "Mise a jour SERVWEB IIS"
Write-Host "DNS SERVWEB        : $ServwebDns"
Write-Host "DNS Expedition     : $ExpeditionDns"
Write-Host "DNS Administration : $AdministrationDns"
Write-Host "Port utilisateur   : $ShortWebPort"
Write-Host "Port diagnostic    : $WebPort"
Write-Host "API centrale       : $ApiBaseUrl"
Write-Host "Depot Git          : $SourcePath"
Write-Host "Dossier deploy     : $DeployPath"
Write-Host "Environnement ASP  : $AspNetCoreEnvironment"

Import-IisModuleOrStop
Assert-PathExists $DeployPath "Dossier de deploiement introuvable. Lance d'abord setup-servweb-iis.ps1"
if (-not (Get-Website -Name $SiteName -ErrorAction SilentlyContinue)) {
    throw "Site IIS introuvable : $SiteName. Lance d'abord setup-servweb-iis.ps1"
}

[Environment]::SetEnvironmentVariable("ExpeditionApi__BaseUrl", $ApiBaseUrl, "Machine")
$env:ExpeditionApi__BaseUrl = $ApiBaseUrl

Stop-PortProcessIfNeeded -Port $WebPort
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
Ensure-WebConfigEnvironment -WebConfigPath (Join-Path $DeployPath "web.config")
Grant-AppPoolPermissions
Ensure-WebBindings
Ensure-FirewallRules
Restart-IisSite
Test-Deployment

Write-Step "Mise a jour terminee"
Write-Host "URL Expedition courte : http://${ExpeditionDns}" -ForegroundColor Green
Write-Host "URL Admin courte      : http://${AdministrationDns}" -ForegroundColor Green
Write-Host "URL diagnostic locale : http://localhost:$WebPort/expedition" -ForegroundColor Green
Write-Host "URL diagnostic DNS    : http://${ServwebDns}:$WebPort/expedition" -ForegroundColor Green
Write-Host "API centrale DNS      : $ApiBaseUrl" -ForegroundColor Green

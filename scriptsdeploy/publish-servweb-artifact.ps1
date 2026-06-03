param(
    [string]$SourceCommitMessage = "Mise a jour SERVWEB",
    [string]$RepoRoot = "",
    [string]$Configuration = "Release",
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$ProjectPath = Join-Path $RepoRoot "src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj"
$TempRoot = Join-Path $env:TEMP "MobileSLI.Expedition.Web.publish"
$PublishTemp = Join-Path $TempRoot "publish"
$ArtifactDir = Join-Path $RepoRoot "artifacts\servweb"
$ArtifactZip = Join-Path $ArtifactDir "MobileSLI.Expedition.Web.zip"
$ManifestPath = Join-Path $ArtifactDir "manifest.json"

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

function Invoke-Checked {
    param(
        [scriptblock]$Command,
        [string]$ErrorMessage
    )

    & $Command

    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Get-CurrentBranch {
    $branch = git rev-parse --abbrev-ref HEAD

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
        throw "Impossible de determiner la branche Git courante."
    }

    return $branch.Trim()
}

function Commit-SourceChangesIfNeeded {
    $status = git status --porcelain

    if ([string]::IsNullOrWhiteSpace(($status -join "`n"))) {
        Write-Host "Aucune modification source a committer."
        return
    }

    Write-Host "Modifications detectees. Commit source en cours."
    git add --all

    if ($LASTEXITCODE -ne 0) {
        throw "git add --all a echoue."
    }

    git reset -- artifacts/servweb 2>$null

    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Aucune modification source stagee hors artefact."
        return
    }

    git commit -m $SourceCommitMessage

    if ($LASTEXITCODE -ne 0) {
        throw "git commit source a echoue."
    }
}

function Commit-ArtifactIfNeeded {
    param([string]$SourceCommitShort)

    git add -f "artifacts/servweb/MobileSLI.Expedition.Web.zip" "artifacts/servweb/manifest.json"

    if ($LASTEXITCODE -ne 0) {
        throw "git add artefact a echoue."
    }

    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Aucune modification d'artefact a committer."
        return
    }

    git commit -m "Publie artefact SERVWEB $SourceCommitShort"

    if ($LASTEXITCODE -ne 0) {
        throw "git commit artefact a echoue."
    }
}

Write-Step "Publication artefact SERVWEB"
Write-Host "Depot local      : $RepoRoot"
Write-Host "Projet           : $ProjectPath"
Write-Host "Configuration    : $Configuration"
Write-Host "Artefact Git     : $ArtifactZip"
Write-Host "Manifest Git     : $ManifestPath"

Set-Location $RepoRoot

Assert-PathExists $ProjectPath "Projet introuvable"

$insideWorkTree = git rev-parse --is-inside-work-tree
if ($LASTEXITCODE -ne 0 -or $insideWorkTree.Trim() -ne "true") {
    throw "Le dossier n'est pas un depot Git valide : $RepoRoot"
}

$branch = Get-CurrentBranch
Write-Host "Branche Git      : $branch"

Write-Step "Synchronisation Git"
git fetch origin
if ($LASTEXITCODE -ne 0) {
    throw "git fetch origin a echoue."
}

git pull --ff-only
if ($LASTEXITCODE -ne 0) {
    throw "git pull --ff-only a echoue. Corrige le Git local avant de publier."
}

Write-Step "Commit source si necessaire"
Commit-SourceChangesIfNeeded

$sourceCommit = (git rev-parse HEAD).Trim()
$sourceCommitShort = (git rev-parse --short HEAD).Trim()

Write-Step "Build et publish local"
Remove-Item -Recurse -Force $TempRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $PublishTemp | Out-Null

Invoke-Checked `
    -Command { dotnet restore $ProjectPath } `
    -ErrorMessage "dotnet restore a echoue."

Invoke-Checked `
    -Command { dotnet build $ProjectPath -c $Configuration --no-restore } `
    -ErrorMessage "dotnet build a echoue."

Invoke-Checked `
    -Command { dotnet publish $ProjectPath -c $Configuration -o $PublishTemp --no-build } `
    -ErrorMessage "dotnet publish a echoue."

Assert-PathExists (Join-Path $PublishTemp "MobileSLI.Expedition.Web.dll") "DLL publiee introuvable"
Assert-PathExists (Join-Path $PublishTemp "web.config") "web.config publie introuvable"

Write-Step "Creation manifest"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

$manifest = [ordered]@{
    project = "MobileSLI.Expedition.Web"
    artifact = "artifacts/servweb/MobileSLI.Expedition.Web.zip"
    sourceCommit = $sourceCommit
    sourceCommitShort = $sourceCommitShort
    branch = $branch
    configuration = $Configuration
    createdAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss K")
    createdOn = $env:COMPUTERNAME
    deployTarget = "SERVWEB IIS"
    serverBuild = $false
    note = "Artefact publie localement. SERVWEB ne compile pas."
}

$manifestJson = $manifest | ConvertTo-Json -Depth 5
$manifestJson | Set-Content -Path $ManifestPath -Encoding UTF8
$manifestJson | Set-Content -Path (Join-Path $PublishTemp "manifest.json") -Encoding UTF8
"$sourceCommitShort $sourceCommit" | Set-Content -Path (Join-Path $PublishTemp "_commit.txt") -Encoding UTF8

Write-Step "Creation ZIP artefact"
Remove-Item -Force $ArtifactZip -ErrorAction SilentlyContinue

Compress-Archive `
    -Path (Join-Path $PublishTemp "*") `
    -DestinationPath $ArtifactZip `
    -Force

Assert-PathExists $ArtifactZip "ZIP artefact introuvable apres creation"

$zipInfo = Get-Item $ArtifactZip
Write-Host "ZIP cree : $($zipInfo.FullName)"
Write-Host "Taille   : $([math]::Round($zipInfo.Length / 1MB, 2)) Mo"

Write-Step "Commit artefact"
Commit-ArtifactIfNeeded -SourceCommitShort $sourceCommitShort

Write-Step "Push"
if ($NoPush) {
    Write-Host "Option -NoPush active : push ignore."
}
else {
    git push origin $branch

    if ($LASTEXITCODE -ne 0) {
        throw "git push origin $branch a echoue."
    }
}

Write-Step "Publication terminee"
Write-Host "Artefact Git : artifacts/servweb/MobileSLI.Expedition.Web.zip"
Write-Host "Manifest     : artifacts/servweb/manifest.json"
Write-Host "Commit       : $sourceCommitShort"

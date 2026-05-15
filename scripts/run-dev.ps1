$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj"

dotnet restore $project
dotnet run --project $project

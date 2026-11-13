#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$compiler = & (Join-Path $PSScriptRoot 'Get-LabBicep.ps1')
$outputDirectory = Join-Path $repoRoot 'artifacts'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
& $compiler build (Join-Path $repoRoot 'infra/main.bicep') --outfile (Join-Path $outputDirectory 'main.json')
if ($LASTEXITCODE -ne 0) {
    throw "Bicep compilation failed with exit code $LASTEXITCODE."
}
Write-Host 'PASS: main.bicep and its network module compile. Azure deployment and packet behavior are not yet validated.'

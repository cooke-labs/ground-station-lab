#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$context = Get-AzContext
if ($null -eq $context -or $context.Subscription.Name -ne 'ground-station-lab') {
    throw 'Select the ground-station-lab subscription with Set-AzContext before previewing.'
}

$groupName = 'rg-ground-station-lab'
$region = 'westus2'
$lookupError = $null
$group = Get-AzResourceGroup -Name $groupName -ErrorAction SilentlyContinue -ErrorVariable lookupError
if ($null -eq $group) {
    if ($lookupError -and ($lookupError[0].Exception.Message -notmatch 'does not exist|not found')) {
        throw $lookupError[0]
    }
    Write-Host "Creating empty resource group $groupName in $region."
    $group = New-AzResourceGroup -Name $groupName -Location $region -ErrorAction Stop
}
if ($group.Location -ne $region) {
    throw "Existing resource group is in $($group.Location), expected $region."
}
if (Get-AzResource -ResourceGroupName $groupName -ErrorAction Stop | Select-Object -First 1) {
    throw 'The lab resource group already has resources; inspect them before previewing this template.'
}

$compiler = & (Join-Path $PSScriptRoot 'Get-LabBicep.ps1')
$env:PATH = "$(Split-Path $compiler -Parent)$([IO.Path]::PathSeparator)$env:PATH"
& (Join-Path $PSScriptRoot 'Test-LabBicep.ps1')

Write-Host 'Previewing network changes only. This does not deploy the VNet or NSGs.'
New-AzResourceGroupDeployment -Name 'checkpoint-01-network' `
    -ResourceGroupName $groupName `
    -TemplateFile (Join-Path $repoRoot 'infra/network.bicep') `
    -TemplateParameterObject @{ namePrefix = 'gsdl'; location = $region } `
    -WhatIf -WhatIfResultFormat FullResourcePayload -ErrorAction Stop

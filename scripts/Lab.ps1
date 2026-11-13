#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Deploy', 'Start', 'Stop', 'Status', 'Remove')]
    [string]$Action,

    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13
$groupName = 'rg-ground-station-lab'
$region = 'westus2'
$projectTag = 'ground-station-lab'
$repoRoot = Split-Path $PSScriptRoot -Parent
$scopePath = Join-Path $repoRoot '.private/lab-scope.json'

$context = Get-AzContext
if ($null -eq $context -or $context.Subscription.Name -ne 'ground-station-lab') {
    throw 'Select the ground-station-lab subscription with Set-AzContext first.'
}

$group = $null
try { $group = Get-AzResourceGroup -Name $groupName -ErrorAction Stop }
catch {
    if ($_.Exception.Message -notmatch 'does not exist|not found') { throw }
}

if ($Action -eq 'Deploy' -and $null -eq $group) {
    if (-not $Execute) {
        Write-Host "Preview: would create resource group $groupName in $region. Use -Execute to create it."
        return
    }
    if ($PSCmdlet.ShouldProcess($groupName, 'Create dedicated lab resource group')) {
        $group = New-AzResourceGroup -Name $groupName -Location $region -Tag @{ project = $projectTag } -ErrorAction Stop
    }
}

if ($null -eq $group) {
    Write-Host "Lab group $groupName does not exist."
    return
}
if ($group.Location -ne $region) { throw "Expected $region; found $($group.Location)." }

if ($Action -eq 'Deploy' -and $group.Tags.project -ne $projectTag) {
    $existing = @(Get-AzResource -ResourceGroupName $groupName -ErrorAction Stop)
    $approvedNames = @('gsdl-vnet', 'gsdl-sim-nsg', 'gsdl-ground-nsg')
    $unexpected = @($existing | Where-Object { $_.Name -notin $approvedNames })
    if ($unexpected.Count) { throw 'Existing untagged group contains unexpected resources; inspect before adopting it.' }
    if ($Execute -and $PSCmdlet.ShouldProcess($groupName, 'Tag as this lab')) {
        $newTags = @{}; if ($group.Tags) { foreach ($key in $group.Tags.Keys) { $newTags[$key] = $group.Tags[$key] } }
        $newTags.project = $projectTag
        $group = Set-AzResourceGroup -Name $groupName -Tag $newTags -ErrorAction Stop
    }
}
if ($Action -ne 'Deploy' -and $group.Tags.project -ne $projectTag) {
    throw 'Resource group lacks the lab ownership tag. Run Deploy preview and review adoption first.'
}

if ($Action -eq 'Deploy') {
    $compiler = & (Join-Path $PSScriptRoot 'Get-LabBicep.ps1')
    $env:PATH = "$(Split-Path $compiler -Parent)$([IO.Path]::PathSeparator)$env:PATH"
    $deployment = @{
        Name = 'ground-station-lab'
        ResourceGroupName = $groupName
        TemplateFile = (Join-Path $repoRoot 'infra/network.bicep')
        TemplateParameterObject = @{ namePrefix = 'gsdl'; location = $region }
        ErrorAction = 'Stop'
    }
    if (-not $Execute) {
        New-AzResourceGroupDeployment @deployment -WhatIf -WhatIfResultFormat FullResourcePayload
        return
    }
    if ($PSCmdlet.ShouldProcess($groupName, 'Deploy network template')) {
        $result = New-AzResourceGroupDeployment @deployment
        if ($result.ProvisioningState -ne 'Succeeded') { throw "Deployment ended in $($result.ProvisioningState)." }
        New-Item -ItemType Directory -Path (Split-Path $scopePath -Parent) -Force | Out-Null
        @{ subscriptionId = $context.Subscription.Id; resourceGroupId = $group.ResourceId } |
            ConvertTo-Json | Set-Content -LiteralPath $scopePath
        Write-Host 'Lab network deployment succeeded. Scope pin saved locally in ignored .private/.'
    }
    return
}

if (-not (Test-Path -LiteralPath $scopePath)) {
    throw 'Local scope pin missing. Run Lab.ps1 -Action Deploy to verify and pin this group first.'
}
$scopePin = Get-Content -LiteralPath $scopePath -Raw | ConvertFrom-Json
if ($scopePin.subscriptionId -ne $context.Subscription.Id -or $scopePin.resourceGroupId -ne $group.ResourceId) {
    throw 'Subscription or resource group differs from the locally pinned lab scope.'
}

if ($Action -eq 'Status') {
    $resources = @(Get-AzResource -ResourceGroupName $groupName -ErrorAction Stop)
    $resources | Group-Object ResourceType | Select-Object Name,Count | Sort-Object Name
    $vms = @(Get-AzVM -ResourceGroupName $groupName -Status -ErrorAction Stop)
    $vms | Select-Object Name,@{n='PowerState';e={$_.Statuses | Where-Object Code -like 'PowerState/*' | Select-Object -ExpandProperty DisplayStatus}}
    return
}

if ($Action -in @('Start', 'Stop')) {
    $vms = @(Get-AzVM -ResourceGroupName $groupName -Status -ErrorAction Stop)
    if (-not $vms.Count) { Write-Host 'No VMs in the lab group.'; return }
    foreach ($vm in $vms) {
        if (-not $Execute) { Write-Host "Preview: $Action VM $($vm.Name). Use -Execute to apply."; continue }
        if ($PSCmdlet.ShouldProcess($vm.Name, "$Action lab VM")) {
            if ($Action -eq 'Start') { Start-AzVM -ResourceGroupName $groupName -Name $vm.Name -ErrorAction Stop | Out-Null }
            else { Stop-AzVM -ResourceGroupName $groupName -Name $vm.Name -Force -ErrorAction Stop | Out-Null }
            Write-Host "$Action completed for $($vm.Name)."
        }
    }
    return
}

if ($Action -eq 'Remove') {
    $resources = @(Get-AzResource -ResourceGroupName $groupName -ErrorAction Stop)
    $resources | Select-Object Name,ResourceType | Format-Table -AutoSize
    if (-not $Execute) {
        Write-Host 'Preview only. -Execute permanently removes this resource group and all listed resources.'
        Remove-AzResourceGroup -Name $groupName -WhatIf
        return
    }
    if ($PSCmdlet.ShouldProcess($groupName, 'Permanently remove lab resource group and all resources')) {
        Remove-AzResourceGroup -Name $groupName -Force -ErrorAction Stop | Out-Null
        if (Get-AzResourceGroup -Name $groupName -ErrorAction SilentlyContinue) {
            throw 'Removal request returned, but resource group still exists. Check Azure before considering cleanup complete.'
        }
        Remove-Item -LiteralPath $scopePath -ErrorAction Stop
        Write-Host 'Lab resource group removed. Local scope pin cleared.'
    }
}

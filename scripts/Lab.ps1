#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Deploy', 'Start', 'Stop', 'Status', 'Remove')]
    [string]$Action,

    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
$groupName = 'rg-ground-station-lab'
$region = 'westus2'
$repoRoot = Split-Path $PSScriptRoot -Parent

$context = Get-AzContext
if ($null -eq $context -or $context.Subscription.Name -ne 'ground-station-lab') {
    throw 'Select the ground-station-lab subscription with Set-AzContext first.'
}

if ($Action -eq 'Deploy') {
    $deployment = @{
        Name = 'ground-station-lab'
        Location = $region
        TemplateFile = (Join-Path $repoRoot 'infra/main.bicep')
        ErrorAction = 'Stop'
    }
    if (-not $Execute) {
        New-AzSubscriptionDeployment @deployment -WhatIf -WhatIfResultFormat FullResourcePayload
        return
    }
    if ($PSCmdlet.ShouldProcess($groupName, 'Deploy lab Bicep template')) {
        $result = New-AzSubscriptionDeployment @deployment
        if ($result.ProvisioningState -ne 'Succeeded') { throw "Deployment ended in $($result.ProvisioningState)." }
        Write-Host 'Lab deployment succeeded.'
    }
    return
}

$group = Get-AzResourceGroup -Name $groupName -ErrorAction Stop
if ($group.Location -ne $region -or $group.Tags.project -ne 'ground-station-lab') {
    throw 'Resource group region or ownership tag does not match this lab.'
}

if ($Action -eq 'Status') {
    Get-AzResource -ResourceGroupName $groupName -ErrorAction Stop |
        Group-Object ResourceType | Select-Object Name,Count | Sort-Object Name
    Get-AzVM -ResourceGroupName $groupName -Status -ErrorAction Stop |
        Select-Object Name,@{n='PowerState';e={$_.Statuses | Where-Object Code -like 'PowerState/*' | Select-Object -ExpandProperty DisplayStatus}}
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
    Get-AzResource -ResourceGroupName $groupName -ErrorAction Stop |
        Select-Object Name,ResourceType | Format-Table -AutoSize
    if (-not $Execute) {
        Write-Host 'Preview only. -Execute permanently removes this resource group and all listed resources.'
        Remove-AzResourceGroup -Name $groupName -WhatIf
        return
    }
    if ($PSCmdlet.ShouldProcess($groupName, 'Permanently remove lab resource group and all resources')) {
        Remove-AzResourceGroup -Name $groupName -Force -ErrorAction Stop | Out-Null
        Write-Host 'Lab resource group removal requested. Check Azure for completion.'
    }
}

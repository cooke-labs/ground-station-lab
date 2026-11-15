#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Budget', 'Deploy', 'Start', 'Stop', 'Status', 'RemoveCompute', 'Remove')]
    [string]$Action,

    [switch]$IncludeCompute,

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

if ($IncludeCompute -and $Action -ne 'Deploy') {
    throw '-IncludeCompute applies only to -Action Deploy.'
}

if ($Action -in @('Budget', 'Deploy')) {
    $compiler = & (Join-Path $PSScriptRoot 'Get-LabBicep.ps1')
    $compilerDirectory = Split-Path $compiler -Parent
    $env:PATH = "$compilerDirectory$([IO.Path]::PathSeparator)$env:PATH"
}

if ($Action -eq 'Budget') {
    $contact = $context.Account.Id
    if ($contact -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        throw 'The selected Azure account is not an email address; deploy infra/budget.bicep with a private contactEmail parameter.'
    }
    $monthStart = [datetime]::UtcNow.ToString('yyyy-MM-01')
    $nextMonth = [datetime]::UtcNow.AddMonths(1).ToString('yyyy-MM-01')
    $deployment = @{
        Name = 'gsdl-budget'
        ResourceGroupName = $groupName
        TemplateFile = (Join-Path $repoRoot 'infra/budget.bicep')
        TemplateParameterObject = @{ amount = 150; startDate = $monthStart; endDate = $nextMonth; contactEmail = $contact }
        ErrorAction = 'Stop'
    }
    if (-not $Execute) {
        New-AzResourceGroupDeployment @deployment -WhatIf -WhatIfResultFormat FullResourcePayload
        return
    }
    if ($PSCmdlet.ShouldProcess($groupName, 'Deploy $150 monthly cost budget and alerts')) {
        $result = New-AzResourceGroupDeployment @deployment
        if ($result.ProvisioningState -ne 'Succeeded') { throw "Budget deployment ended in $($result.ProvisioningState)." }
        Write-Host 'Budget deployment succeeded. Alerts do not cap spending.'
    }
    return
}

if ($Action -eq 'Deploy') {
    $deployment = @{
        Name = 'ground-station-lab'
        Location = $region
        TemplateFile = (Join-Path $repoRoot 'infra/main.bicep')
        ErrorAction = 'Stop'
    }
    if ($IncludeCompute) {
        $keyPath = Join-Path $env:USERPROFILE '.ssh/id_ed25519.pub'
        if (-not (Test-Path -LiteralPath $keyPath)) { throw "SSH public key missing at $keyPath." }
        $sshPublicKey = (Get-Content -LiteralPath $keyPath -Raw).Trim()
        if ($sshPublicKey -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+(?:\s+.*)?$') {
            throw 'Expected an ed25519 SSH public key.'
        }
        $deployment.TemplateParameterObject = @{ deployCompute = $true; sshPublicKey = $sshPublicKey }
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

if ($Action -eq 'RemoveCompute') {
    function Test-LabComputeResource($resource) {
        switch ($resource.ResourceType) {
            'Microsoft.Compute/virtualMachines' { return $resource.Name -in @('gsdl-sim-vm', 'gsdl-ground-vm') }
            'Microsoft.Compute/disks' { return $resource.Name -match '^gsdl-(sim|ground)-vm_OsDisk_' }
            'Microsoft.Network/networkInterfaces' { return $resource.Name -in @('gsdl-sim-vm-nic', 'gsdl-ground-vm-nic') }
            'Microsoft.Network/publicIPAddresses' { return $resource.Name -in @('gsdl-sim-vm-pip', 'gsdl-ground-vm-pip') }
            'Microsoft.DevTestLab/schedules' { return $resource.Name -in @('shutdown-computevm-gsdl-sim-vm', 'shutdown-computevm-gsdl-ground-vm') }
            default { return $false }
        }
    }
    $resources = @(Get-AzResource -ResourceGroupName $groupName -ErrorAction Stop | Where-Object { Test-LabComputeResource $_ })
    if (-not $resources.Count) { Write-Host 'No lab compute resources remain.'; return }
    $resources | Select-Object Name,ResourceType | Sort-Object ResourceType,Name | Format-Table -AutoSize
    if (-not $Execute) { Write-Host 'Preview only. Use -Execute to delete these VM resources, disks and public IPs.'; return }
    if (-not $PSCmdlet.ShouldProcess($groupName, 'Delete lab VMs, disks, NICs, public IPs and shutdown schedules')) { return }
    foreach ($schedule in @($resources | Where-Object ResourceType -eq 'Microsoft.DevTestLab/schedules')) {
        Remove-AzResource -ResourceId $schedule.ResourceId -Force -ErrorAction Stop | Out-Null
    }
    foreach ($vm in @($resources | Where-Object ResourceType -eq 'Microsoft.Compute/virtualMachines')) {
        Remove-AzVM -ResourceGroupName $groupName -Name $vm.Name -Force -ErrorAction Stop | Out-Null
    }
    foreach ($type in @('Microsoft.Network/networkInterfaces', 'Microsoft.Compute/disks', 'Microsoft.Network/publicIPAddresses')) {
        $leftovers = @(Get-AzResource -ResourceGroupName $groupName -ResourceType $type -ErrorAction Stop | Where-Object { Test-LabComputeResource $_ })
        foreach ($resource in $leftovers) {
            Remove-AzResource -ResourceId $resource.ResourceId -Force -ErrorAction Stop | Out-Null
        }
    }
    $remaining = @(Get-AzResource -ResourceGroupName $groupName -ErrorAction Stop | Where-Object { Test-LabComputeResource $_ })
    if ($remaining.Count) { throw "Compute cleanup incomplete: $($remaining.Name -join ', ')." }
    Write-Host 'Lab compute resources removed. Network and budget remain.'
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

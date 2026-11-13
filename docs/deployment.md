# Network foundation

The current template defines one VNet, two private subnets, and two NSGs. It creates no VMs, public IPs or monitoring workspace. Configuration and packet-flow verification in Azure are still pending.

## Requirements and local validation

- PowerShell 7 (`pwsh`) on Windows x64 or Linux x64.
- `Az.Accounts`, `Az.Resources` and `Az.Network` modules for deployment/inspection.
- An Azure subscription and suitable resource deployment permissions.

From the repository root:

```powershell
./scripts/Test-LabBicep.ps1
```

This downloads the pinned standalone Bicep compiler from Microsoft's official release, checks its SHA-256, and compiles the template into ignored `artifacts/`. It does not authenticate to Azure or deploy anything. The CI workflow runs the same check with read-only repository permissions. Compilation does not establish deployed network behavior.

## Preview and deploy with Azure PowerShell

For the first preview, run `./scripts/Preview-Network.ps1` from this repository in your signed-in PowerShell 7 terminal. It verifies the selected subscription, creates the empty dedicated resource group if needed, refuses to proceed if that group already contains resources, and runs a network what-if. Share a redacted preview for review before applying. The equivalent commands are shown below for transparency.

```powershell
Connect-AzAccount
Get-AzContext  # Verify the intended subscription before proceeding.

$labBicep = & ./scripts/Get-LabBicep.ps1
$env:PATH = "$(Split-Path $labBicep -Parent)$([IO.Path]::PathSeparator)$env:PATH"
$labGroup = 'rg-ground-station-lab'
$labRegion = 'westus2'

# Use a dedicated lab group. Check for an existing group before creating it.
$existingGroup = Get-AzResourceGroup -Name $labGroup -ErrorAction SilentlyContinue
if ($null -eq $existingGroup) {
    New-AzResourceGroup -Name $labGroup -Location $labRegion -ErrorAction Stop
}

$networkDeployment = @{
    Name = 'checkpoint-01-network'
    ResourceGroupName = $labGroup
    TemplateFile = './infra/network.bicep'
    TemplateParameterObject = @{ namePrefix = 'gsdl'; location = $labRegion }
    ErrorAction = 'Stop'
}
New-AzResourceGroupDeployment @networkDeployment -WhatIf -WhatIfResultFormat FullResourcePayload
```

Review the expected VNet and two NSGs, subnet ranges and rule priorities. Check any existing resources before proceeding. The resource group creation above is a real operation; the subsequent what-if previews the network deployment.

After reviewing that preview:

```powershell
$deployment = New-AzResourceGroupDeployment @networkDeployment
$deployment | Select-Object ProvisioningState
Get-AzVirtualNetwork -ResourceGroupName $labGroup -Name 'gsdl-vnet'
Get-AzNetworkSecurityGroup -ResourceGroupName $labGroup |
    Select-Object Name, SecurityRules
```

The current rules apply to exactly the two documented subnets. Reassess the policy before adding other subnets or peerings. Default outbound access is explicitly disabled; future hosts need an explicit egress path. No VM administration rule exists yet. Packet tests require the later hosts and receiver.

Do not publish raw outputs containing account or subscription identifiers. Record sanitized deployment and test evidence separately.

[Microsoft PowerShell deployment reference](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-powershell)

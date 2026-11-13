# Network foundation

The [subscription-level Bicep entrypoint](../infra/main.bicep) defines the dedicated resource group, its ownership tag and the [network module](../infra/network.bicep). The network has one VNet, two private subnets and two NSGs. It has no VMs, public IPs or monitoring workspace. The network was deployed and read back on 2026-11-13; see [sanitized evidence](../evidence/public/network-2026-11-13.md). Packet tests are pending.

## Validate locally without Azure

From the repository root in PowerShell 7:

```powershell
./scripts/Test-LabBicep.ps1
```

This compiles `main.bicep` and its network module with a pinned, hash-checked Bicep compiler. It does not make Azure calls. CI runs the same check. Compilation proves template syntax, not live network behavior.

## Preview from Azure Cloud Shell PowerShell

The local PowerShell client has repeatedly lost TLS handshakes to Azure Resource Manager. Use [Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/overview) in **PowerShell** mode to run the deployment from an Azure-hosted environment. An [ephemeral session](https://learn.microsoft.com/en-us/azure/cloud-shell/get-started/ephemeral) does not require a storage account; its files disappear when the session ends. Cloud Shell is an alternate execution location, not a replacement for the Bicep source in GitHub.

In Cloud Shell PowerShell:

```powershell
Set-AzContext -Subscription 'ground-station-lab'
git clone https://github.com/cooke-labs/ground-station-lab.git
Set-Location ./ground-station-lab
New-AzSubscriptionDeployment -Name ground-station-lab -Location westus2 -TemplateFile ./infra/main.bicep -WhatIf -WhatIfResultFormat FullResourcePayload
```

The last command is a preview. It makes no resource changes. Review the group tag, VNet, subnet prefixes and NSG rule changes. Because the three network resources already exist, inspect any proposed modification before deploying. Do not treat a what-if result as proof that packets flow as intended.

After reviewing the preview, apply the same Bicep file with Azure PowerShell:

```powershell
New-AzSubscriptionDeployment -Name ground-station-lab -Location westus2 -TemplateFile ./infra/main.bicep
```

The template is declarative and can be deployed again to converge the listed resources. Keep later VM and monitoring resources inside the dedicated group and add them to the Bicep entrypoint. Use the [lifecycle guide](lifecycle.md) for stopping VMs and tearing down the group.

The current rules apply to exactly the two documented subnets. Reassess them before adding other subnets or peerings. Default outbound access is explicitly disabled; future hosts need an egress path. No VM administration rule exists yet.

Do not publish raw outputs containing account or subscription identifiers. Record sanitized deployment and test evidence separately.

[Microsoft: deploy Bicep from Cloud Shell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cloud-shell) · [Microsoft: what-if](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-what-if)

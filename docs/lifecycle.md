# Lab lifecycle and cost control

The [Bicep entrypoint](../infra/main.bicep) is the infrastructure definition. It creates or updates the dedicated `rg-ground-station-lab` resource group in `westus2` and its network module. [Preview and deploy it](deployment.md) with `New-AzSubscriptionDeployment` from your local PowerShell terminal. The script below is a convenience wrapper for operations; it is not the infrastructure definition.

From the repository root in PowerShell 7, with the `ground-station-lab` subscription selected:

```powershell
./scripts/Lab.ps1 -Action Deploy            # One Azure what-if operation; no preflight inventory
./scripts/Lab.ps1 -Action Deploy -Execute   # Apply the Bicep entrypoint
./scripts/Lab.ps1 -Action Status            # Inventory resources and VM power states
./scripts/Lab.ps1 -Action Stop              # Preview VM deallocation
./scripts/Lab.ps1 -Action Stop -Execute     # Deallocate all VMs in the lab group
./scripts/Lab.ps1 -Action Start -Execute    # Start lab VMs
./scripts/Lab.ps1 -Action Remove            # Inventory and preview full teardown
./scripts/Lab.ps1 -Action Remove -Execute   # Delete the dedicated resource group
```

The wrapper checks the selected subscription name locally. Its `Deploy` action submits one subscription-level Bicep deployment or what-if operation. It does not first call Azure to inspect the group or tag it. Other actions verify the resource group's location and ownership tag before acting.

`Stop -Execute` deallocates VM compute. Managed disks, public IPs, storage and workspace ingestion/retention can still incur charges while VMs are off. `Remove -Execute` destroys the entire dedicated group, including any evidence stored only inside it. Export and sanitize evidence first. Never store the only copy of project material in a VM disk.

The current deployment has no VM, public IP or workspace. No scheduled auto-shutdown or Azure cost budget exists yet. Before provisioning VMs, price the selected SKU, disks and IPs in West US 2; configure a budget alert and shutdown schedule. Azure budgets notify but do not cap charges. If later work creates subscription-scoped diagnostics, role assignments or identities, extend the teardown procedure and inventory those separately before claiming full cleanup.

[Stop-AzVM deallocation behavior](https://learn.microsoft.com/en-us/powershell/module/az.compute/stop-azvm) · [Remove-AzResourceGroup behavior](https://learn.microsoft.com/en-us/powershell/module/az.resources/remove-azresourcegroup)

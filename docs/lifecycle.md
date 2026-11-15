# Lab lifecycle and cost control

The [Bicep entrypoint](../infra/main.bicep) is the infrastructure definition. It creates or updates the dedicated `rg-ground-station-lab` resource group in `westus2` and its network module. [Preview and deploy it](deployment.md) with `New-AzSubscriptionDeployment` from your local PowerShell terminal. The script below is a convenience wrapper for operations; it is not the infrastructure definition.

From the repository root in PowerShell 7, with the `ground-station-lab` subscription selected:

```powershell
./scripts/Lab.ps1 -Action Deploy            # One Azure what-if operation; no preflight inventory
./scripts/Lab.ps1 -Action Deploy -Execute   # Apply the Bicep entrypoint
./scripts/Lab.ps1 -Action Budget            # Preview the $150 monthly budget
./scripts/Lab.ps1 -Action Budget -Execute   # Apply budget and email alerts
./scripts/Lab.ps1 -Action Deploy -IncludeCompute           # Preview two VMs and shutdown schedules
./scripts/Lab.ps1 -Action Deploy -IncludeCompute -Execute  # Create paid compute resources
./scripts/Lab.ps1 -Action Status            # Inventory resources and VM power states
./scripts/Lab.ps1 -Action Stop              # Preview VM deallocation
./scripts/Lab.ps1 -Action Stop -Execute     # Deallocate all VMs in the lab group
./scripts/Lab.ps1 -Action Start -Execute    # Start lab VMs
./scripts/Lab.ps1 -Action RemoveCompute          # Preview deletion of VM resources
./scripts/Lab.ps1 -Action RemoveCompute -Execute # Delete VMs, disks, NICs, IPs and schedules; keep network
./scripts/Lab.ps1 -Action Remove            # Inventory and preview full teardown
./scripts/Lab.ps1 -Action Remove -Execute   # Delete the dedicated resource group
```

The wrapper checks the selected subscription name locally. Its `Deploy` action submits one subscription-level Bicep deployment or what-if operation. It does not first call Azure to inspect the group or tag it. Compute is opt-in and reads the local `~/.ssh/id_ed25519.pub` key without committing it. `Budget` submits a separate resource-group Bicep deployment, using the selected account's email for 50% and 80% alerts. Other actions verify the resource group's location and ownership tag before acting.

`Stop -Execute` deallocates VM compute. Managed disks, public IPs, storage and workspace ingestion/retention can still incur charges while VMs are off. `Remove -Execute` destroys the entire dedicated group, including any evidence stored only inside it. Export and sanitize evidence first. Never store the only copy of project material in a VM disk.

`RemoveCompute -Execute` is the repeatable low-cost reset for the current two-VM design. It inventories only the named lab VMs and supporting resources, deletes schedules and VMs, then removes any remaining named NICs, OS disks and public IPs. It verifies cleanup, leaving the VNet, NSGs and cost budget. Re-run it after a failed connection; it is safe when no compute resources remain. A normal `Deploy` is network-only; use `Deploy -IncludeCompute -Execute` to recreate the VMs. For a full reset, `Remove -Execute` deletes the entire resource group, including the network and budget. Recreate the group/network with `Deploy -Execute`, then the budget with `Budget -Execute`.

The lab has a $150 monthly Azure budget with 50% and 80% alerts. Azure budgets notify but do not cap charges. The compute template adds two daily 03:00 Pacific automatic VM shutdown schedules; deallocate manually when finished sooner. Verify those schedules after deployment. The current plan has no workspace or Sentinel ingestion yet. If later work creates subscription-scoped diagnostics, role assignments or identities, extend the teardown procedure and inventory those separately before claiming full cleanup.

[Stop-AzVM deallocation behavior](https://learn.microsoft.com/en-us/powershell/module/az.compute/stop-azvm) · [Remove-AzResourceGroup behavior](https://learn.microsoft.com/en-us/powershell/module/az.resources/remove-azresourcegroup)

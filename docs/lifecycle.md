# Lab lifecycle and cost control

Use PowerShell 7 with the `Az.Accounts`, `Az.Resources` and `Az.Compute` modules. Sign in to the intended subscription first. All commands below use the dedicated `rg-ground-station-lab` resource group in `westus2`.

```powershell
./scripts/Lab.ps1 -Action Deploy            # Preview current infrastructure
./scripts/Lab.ps1 -Action Deploy -Execute   # Apply current infrastructure and pin its subscription/group IDs locally
./scripts/Lab.ps1 -Action Status            # Inventory resources and VM power states
./scripts/Lab.ps1 -Action Stop              # Preview VM deallocation
./scripts/Lab.ps1 -Action Stop -Execute     # Deallocate all VMs in the lab group
./scripts/Lab.ps1 -Action Start -Execute    # Start lab VMs for the next session
./scripts/Lab.ps1 -Action Remove            # Inventory and preview full teardown
./scripts/Lab.ps1 -Action Remove -Execute   # Delete the whole dedicated resource group
```

The script checks the selected subscription name, group location and ownership tag. `Deploy -Execute` records the exact subscription and resource group IDs in ignored `.private/lab-scope.json`; later actions refuse a different scope. For the already deployed network, the first `Deploy -Execute` is an idempotent adoption/deployment step, not a second network. Inspect its preview first. On a fresh subscription, the first preview only reports that the empty group would be created; run `Deploy -Execute` to create and deploy the network. The current template contains only a VNet and two NSGs; future VM and monitoring modules must be wired into the same deploy entrypoint and dedicated group before they are considered lifecycle-managed.

`Stop -Execute` deallocates VM compute. Managed disks, public IPs, storage and workspace ingestion/retention can still incur charges while VMs are off. `Remove -Execute` is the full lab teardown; it destroys any evidence stored only inside the group. Export and sanitize evidence first. Never store the only copy of project material in a VM disk.

The current deployment has no VM, public IP or workspace. No scheduled auto-shutdown or Azure cost budget exists yet. Before provisioning VMs, price the selected SKU, disks and IPs in West US 2; configure a budget alert and a shutdown schedule. Azure budgets notify but do not cap charges. If later work creates subscription-scoped diagnostics, role assignments or identities, extend the teardown procedure and inventory those separately before claiming full cleanup.

[Stop-AzVM deallocation behavior](https://learn.microsoft.com/en-us/powershell/module/az.compute/stop-azvm), [Remove-AzResourceGroup behavior](https://learn.microsoft.com/en-us/powershell/module/az.resources/remove-azresourcegroup)

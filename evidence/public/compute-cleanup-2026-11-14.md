# Compute deployment and cleanup checkpoint

Date: 2026-11-14, Pacific time. Azure region: West US 2.

## Result

- Subscription deployment completed with two `Standard_D2as_v6` Ubuntu VMs, two NICs, two Standard public IPs, two OS disks, and two daily shutdown schedules.
- Both VMs were deallocated and verified as `PowerState/deallocated`.
- The two shutdown schedules and VMs were removed. VM removal also deleted their OS disks and NICs. The two remaining public IPs were removed separately.
- A final Azure resource inventory in the dedicated lab group returned only `gsdl-vnet`, `gsdl-sim-nsg`, and `gsdl-ground-nsg`. The separate $150 monthly cost budget was verified through Azure's budget API with 50% and 80% alerts.

## What this proves and does not prove

The subscription accepted the pinned image, VM size, networking, and shutdown schedule template. The cleanup check found no remaining VM, disk, NIC, public IP, or schedule resources in the lab group. It does not prove telemetry flow, guest configuration, or exact billed cost. Azure budget alerts notify; they do not stop charges. Recreate compute only when ready to run the next lab checkpoint.

## Reproduce

From a local PowerShell 7 terminal with the `ground-station-lab` subscription selected, use `./scripts/Lab.ps1 -Action Deploy -IncludeCompute` to preview and add `-Execute` to apply. Use `./scripts/Lab.ps1 -Action RemoveCompute` to preview targeted cleanup and add `-Execute` to remove the two VMs and their supporting resources. Use `./scripts/Lab.ps1 -Action Remove -Execute` for complete resource-group teardown.

No account identifiers, public IP addresses, SSH keys, or raw Azure response bodies are included here.

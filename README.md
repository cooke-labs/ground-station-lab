# Ground Station Defense Lab

**Status: first network checkpoint, 2026-11-13. The VNet and two NSGs are deployed in West US 2. Live packet behavior is not yet validated.**

A public Azure security operations lab: protect a small ground-station analogue, investigate controlled events, and explain the evidence behind selected security controls. All mission data is synthetic. This is an independent educational project, not a representation of any employer's architecture.

The target is a reproducible two-VM network, working log collection and detections, an incident investigation, a hunt, and an evidence-linked control map. The current implementation is the network foundation; hosts and monitoring are not deployed yet.

- [Validate and deploy the network](docs/deployment.md)
- [Stand up, stop and tear down the lab](docs/lifecycle.md)
- [Architecture, telemetry contract, and scenarios](docs/architecture.md)
- [Control mapping plan](docs/control-map.md)
- [SPARTA replay scenario mapping](docs/sparta-mapping.md)
- [Network deployment evidence](evidence/public/network-2026-11-13.md)

Planned demonstration: **generate a mission anomaly → detect it → investigate host, network, and control-plane evidence → choose containment → restore service → show the control evidence and remaining gaps.**

The first checkpoint includes Azure PowerShell deployment instructions. Run `./scripts/Test-LabBicep.ps1` in PowerShell 7 to compile the network template; the script downloads a pinned, checksum-verified standalone Bicep compiler. This check does not deploy resources or prove packet filtering. Security scans and live validation are later milestones. A static explainer is optional; the working lab and investigation are the release criteria.

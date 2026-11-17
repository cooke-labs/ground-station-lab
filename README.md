# Ground Station Defense Lab

**Status: live captured-telemetry replay and receiver mitigation tested on two Azure VMs in West US 2. Compute was removed after evidence export.**

A public Azure security operations lab: protect a small ground-station analogue, investigate controlled events, and explain the evidence behind selected security controls. All mission data is synthetic. This is an independent educational project, not a representation of any employer's architecture.

The completed case compares a benign retry with five exact-payload replay copies. Local D1 analysis flagged the burst. A seeded receiver with duplicate rejection enabled rejected all five copies and accepted three fresh sequences.

- [Mock authorization and assessment package](docs/assessment-package.md)
- [Live replay evidence and SHA-256 manifest](evidence/public/replay-20261116-b/)
- [Application and repeatable replay procedure](app/README.md)
- [Validate and deploy the network](docs/deployment.md)
- [Stand up, stop and tear down the lab](docs/lifecycle.md)
- [Compute candidate and cost gate](docs/compute-decision.md)
- [Architecture, telemetry contract, and scenarios](docs/architecture.md)
- [Control mapping plan](docs/control-map.md)
- [SPARTA replay scenario mapping](docs/sparta-mapping.md)
- [Network deployment evidence](evidence/public/network-2026-11-13.md)
- [Compute deployment and cleanup evidence](evidence/public/compute-cleanup-2026-11-14.md)

Run `./scripts/Test-LabBicep.ps1` in PowerShell 7 to compile the infrastructure definition with the pinned, checksum-verified Bicep compiler. Run `python3 -m unittest discover -s tests -v` for the loopback UDP tests. The assessment explains the current limits on log collection, authentication and replay protection.

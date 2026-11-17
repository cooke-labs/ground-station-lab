# Captured telemetry replay evidence

This case ran on two Azure VMs on November 16, 2026 Pacific. The guest timestamps in these records are UTC. [Mock authorization and assessment package](../../../docs/assessment-package.md)

| Phase | Receiver observations | Local D1 alerts |
|---|---|---|
| [Baseline](baseline/events.jsonl) | Five fresh messages and one accepted benign retry | [0](baseline/analysis.json) |
| [Replay](attack/events.jsonl) | Six cumulative baseline observations and five accepted replay copies | [1](attack/analysis.json) |
| [Mitigated](mitigated/events.jsonl) | One accepted seed, five rejected copies and three fresh messages accepted | [1](mitigated/analysis.json) |

The [capture](baseline/received.bin) is the 215-byte application payload of the first valid received UDP datagram. The sender's [original](original.bin), simulator's [copied capture](receiver-captured.bin), and both later phase captures all have the same SHA-256 digest. The [sender ledger](sender.jsonl) records 20 send actions with matching receiver fingerprints across the two receiver sessions.

The [run metadata](run.json) identifies the tested code by digest and describes the controller recovery. The [test excerpt](test-results.txt) comes from the simulator's loopback tests. The [cleanup inventory](cleanup.json) gives resource counts after compute removal. The [manifest](manifest.json) hashes each evidence record and capture. The publication retains only reviewed synthetic application fields, private lab IPs, a test excerpt and count-only Azure inventory.

From the repository root, reproduce the replay analysis from the published log:

```shell
python3 app/telemetry_lab.py analyze --log evidence/public/replay-20261116-b/attack/events.jsonl
```

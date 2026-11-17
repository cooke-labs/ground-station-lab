# Bounded telemetry replay exercise

`telemetry_lab.py` uses Python 3 standard-library sockets. The receiver is a synthetic ground service, not flight software. No dependencies need installation.

## Run on the Azure lab

From the repository root in local PowerShell 7, select the lab subscription and [deploy the two lab VMs](../docs/lifecycle.md). With both VMs running, use a fresh run ID:

```powershell
./scripts/Invoke-ReplayExercise.ps1 -RunId replay-example-01 -UseManagedRunCommand
```

The controller runs the loopback tests, sends the benign retry and replay burst, tests the receiver policy, and exports guest evidence under `evidence/raw/<run-id>/`. If the controller stops after submitting a command, check that named command and the collected evidence before any further transmission. After export, run `./scripts/Lab.ps1 -Action RemoveCompute -Execute` to remove the VMs and supporting compute resources. [Completed live case](../docs/assessment-package.md)

## Run the application commands

Start on the receiver, using its private IP and a new evidence directory:

```sh
mkdir -p /tmp/gsdl-case
python3 telemetry_lab.py receive --bind 10.42.20.4 --duration 600 --log /tmp/gsdl-case/events.jsonl --capture /tmp/gsdl-case/received.bin
```

Use the actual receiver IP. On the source VM:

```sh
mkdir -p /tmp/gsdl-case
python3 telemetry_lab.py send --destination 10.42.20.4 --count 5 --run-id case-01 --capture /tmp/gsdl-case/original.bin
python3 telemetry_lab.py replay --destination 10.42.20.4 --count 1 --capture /tmp/gsdl-case/original.bin
```

This first replay is the documented benign retry comparison. Analyze on the receiver with `python3 telemetry_lab.py analyze --log /tmp/gsdl-case/events.jsonl`. One duplicate should produce no alert. Wait at least 11 seconds before the controlled burst, then run on the source:

```sh
python3 telemetry_lab.py replay --destination 10.42.20.4 --count 5 --capture /tmp/gsdl-case/original.bin
```

Analyze again. The receiver classifies a message as a duplicate when it repeats a source IP, mission, asset and sequence key. D1 flags the third duplicate from the same source IP and claimed mission/asset within ten seconds. Scenario labels play no role in the analysis. Inspect the sender and receiver SHA-256 fingerprints to corroborate exact payload reuse and use operator and retry context to assess intent. The capture files contain exact UDP application payload bytes without packet headers. Use fresh capture paths for each run because `received.bin` records only the first valid datagram.

For a mitigation comparison, restart the bounded receiver with a fresh log/capture and `--reject-duplicates`. Send the captured original once to establish receiver state, then replay it five times. Duplicates should be rejected. Send a fresh sequence with `send --start-sequence 100` and verify acceptance. The restart clears all duplicate memory; this is a deliberate limitation to document.

## What is demonstrated

Baseline accepts repeated packets while logging duplicate sequence behavior. The mitigated configuration rejects repeated sequence numbers within the current receiver process. Neither configuration authenticates the sender, protects confidentiality, maintains durable anti-replay state, or validates a real space protocol. A forged new sequence can bypass this demonstration's duplicate check. Source IP and asset fields do not prove spacecraft identity.

The destination is restricted to the lab's `10.42.0.0/16` or loopback. Sending is capped at 100 packets per command with at least one second between packets. Receiver duration, packet size, event count, and in-memory state are bounded. Logs are local JSONL; Syslog, AMA and Sentinel ingestion are not implemented by this program.

Run the real loopback UDP tests from the repository root with `python3 -m unittest discover -s tests -v`. Tests mark events as fixtures. Keep fixture output separate from live Azure evidence.

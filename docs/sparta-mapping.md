# SPARTA scenario mapping

The bounded Azure telemetry replay ran on 2026-11-16 Pacific. The [assessment package](assessment-package.md) records the observed delivery, detection and mitigation results.

SPARTA (Space Attack Research & Tactic Analysis) describes space-system adversary behavior. Use it to choose and explain a mission-inspired scenario. NIST/FedRAMP describe control requirements; they serve a different purpose. Technique labels do not establish real spacecraft compromise or regulatory compliance.

## Required scenario: bounded telemetry replay

S1 reuses the first valid synthetic UDP payload captured by the receiver. The simulator resent five copies at one-second spacing. D1 flagged the burst from local receiver records. One deliberate benign retry shared the original fingerprint and stayed below threshold. In the mitigation phase, a fresh receiver accepted the old payload once, rejected the next five copies and accepted three fresh messages. [Evidence manifest](../evidence/public/replay-20261116-b/manifest.json)

Map this to **EX-0001 — Replay**, with relationship `behavioral analogue`. SPARTA describes reusing captured traffic to provoke processing again. Our IP-based ground-receiver exercise does not model an RF link, spacecraft bus, authenticated telecommand acceptance or physical spacecraft effects. Do not assign the Bus Traffic Replay sub-technique to an ordinary VM UDP link. [Official Replay reference](https://sparta.aerospace.org/technique/EX-0001/), [official supporting reference](https://sparta.aerospace.org/countermeasures/references/IA-2)

**IMP-0011 — Command and Data Flow Manipulation** is a secondary conceptual relationship when the exercise deliberately changes duplication, sequence or delivery of mission-like data. A routine privileged Azure NSG edit by itself is not enough to claim this technique: show an intentional traffic effect, and label the spacecraft-context gap. S2 can remain primarily an Azure audit/control exercise. [Official SPARTA technique catalog](https://sparta.aerospace.org/technique/SPARTA), [technique page](https://sparta.aerospace.org/technique/IMP-0011/)

## Evidence for the tested scenario

- Verified technique ID, exact title, source URL, retrieval date and framework version if established; recheck when executing because the catalog can change.
- Diagram marking the simulated spacecraft/link/ground elements and the actual attack surface.
- Captured original message and bounded replay command/configuration; public evidence is sanitized.
- UTC execution window, expected behavior, actual receiver response, application capture and local D1 output. Centralized KQL analysis is outside the scope of this run.
- Benign retry comparison, detection blind spots and whether replay prevention exists. Detection is not prevention.
- Analyst decision, contained lab scope, reversible response, restoration and mission-impact explanation.
- Explicit fit: `behavioral analogue`, with untested RF, flight-software, authentication and mission effects listed.

The assessment relates the evidence to SI-4 monitoring, AU-6 review, IR-4 handling and the permitted SC-7 network path. SPARTA provides the behavioral mapping. The selected NIST control relationships identify the procedures exercised and the gaps that remain.

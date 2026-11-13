# SPARTA scenario mapping

Design record, 2026-11-13. Status: scenario design only; no attack or telemetry run has occurred.

SPARTA (Space Attack Research & Tactic Analysis) describes space-system adversary behavior. Use it to choose and explain a mission-inspired scenario. NIST/FedRAMP describe control requirements; they serve a different purpose. Technique labels do not establish real spacecraft compromise or regulatory compliance.

## Required scenario: bounded telemetry replay

Extend S1 with an intentional replay of a previously captured valid **synthetic lab** UDP message. Preserve its original fields/sequence; resend at a low, capped rate to the owned receiver. Record what the receiver actually accepts/rejects and what the detection observes. Compare with a documented benign retry to study false positives.

Map this to **EX-0001 — Replay**, with relationship `behavioral analogue`. SPARTA describes reusing captured traffic to provoke processing again. Our IP-based ground-receiver exercise does not model an RF link, spacecraft bus, authenticated telecommand acceptance or physical spacecraft effects. Do not assign the Bus Traffic Replay sub-technique to an ordinary VM UDP link. [Official Replay reference](https://sparta.aerospace.org/technique/EX-0001/), [official supporting reference](https://sparta.aerospace.org/countermeasures/references/IA-2)

**IMP-0011 — Command and Data Flow Manipulation** is a secondary conceptual relationship when the exercise deliberately changes duplication, sequence or delivery of mission-like data. A routine privileged Azure NSG edit by itself is not enough to claim this technique: show an intentional traffic effect, and label the spacecraft-context gap. S2 can remain primarily an Azure audit/control exercise. [Official SPARTA technique catalog](https://sparta.aerospace.org/technique/SPARTA), [technique page](https://sparta.aerospace.org/technique/IMP-0011/)

## Required evidence before calling the scenario tested

- Verified technique ID, exact title, source URL, retrieval date and framework version if established; recheck when executing because the catalog can change.
- Diagram marking the simulated spacecraft/link/ground elements and the actual attack surface.
- Captured original message and bounded replay command/configuration; public evidence is sanitized.
- UTC execution window, expected behavior, actual receiver response, relevant log/packet evidence, and KQL result.
- Benign retry comparison, detection blind spots and whether replay prevention exists. Detection is not prevention.
- Analyst decision, contained lab scope, reversible response, restoration and mission-impact explanation.
- Explicit fit: `behavioral analogue`, with untested RF, flight-software, authentication and mission effects listed.

After execution, the case report must connect the SPARTA behavior to the captured message, replay evidence, detection and response. Keep spacecraft anti-replay assurance explicitly outside the demonstrated scope; describe actual results only when evidenced.

Use the same evidence record to relate SI-4 monitoring, AU-6 review, IR-4 handling and relevant network controls. Keep control coverage and adversary-technique coverage as separate fields. MITRE ATT&CK remains useful for ground-host behaviors when there is an actual behavior-specific match.

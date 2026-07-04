# Security Model

## What we protect

The integrity of the accept/reject verdict, and the availability of the pipeline,
against a fully hostile input stream.

## Attacker model

The attacker controls every byte on the wire, indefinitely. There is no
authentication upstream of this parser; it must survive arbitrary,
adversarially-chosen input forever without producing a wrong verdict or wedging.

## Trust boundary

Every byte arriving on the AXI-Stream input is untrusted until each protocol field
has been explicitly validated. Nothing is assumed about length, framing, or
content. Fields are checked; claims (e.g. length) are cross-checked or rejected.

## Threats, controls, and evidence

| ID | Threat | CWE | Control | Evidence |
|----|--------|-----|---------|----------|
| T1 | Wedge / DoS from truncated, oversized, or back-to-back garbage frames | [CWE-1245](https://cwe.mitre.org/data/definitions/1245.html) | Stateless between frames; returns to idle on `tlast`; `tready` never conditionally withheld | `tb/test_fuzz.py` (asserts `tready` held + exactly one verdict/frame); `tb/test_axis_skid.py` random-stall bench; **formal** skid-buffer liveness proof |
| T2 | Parser confusion: lying lengths, spoofed EtherType, forged IP checksum | [CWE-20](https://cwe.mitre.org/data/definitions/20.html) | Validate version/IHL, EtherType, protocol, fragment flags, port, length; recompute IP checksum in hardware | **Formal** no-bad-accept proof (`formal/l1_trigger.sby`: an accept requires all validation flags high); `tb/test_fuzz.py` golden model (300 cases, **0 bad-accepts**); directed `tb/test_ipv4_parser.py` |
| T3 | Cross-packet leakage: one frame influencing the next verdict | [CWE-1272](https://cwe.mitre.org/data/definitions/1272.html) | Fully stateless between packets; match flags cleared at byte 0 | `tb/test_l1_trigger.py` back-to-back; `tb/test_fuzz.py` (300 frames in sequence) |
| T4 | Uninitialized state after power-up or reset | [CWE-1271](https://cwe.mitre.org/data/definitions/1271.html) | **Every** register — control and datapath — has an explicit reset value, so power-up state equals reset state and no `X` can propagate | Synchronous reset of all flops in every `always_ff`; on-hardware bring-up starts correctly with no explicit reset pulse |
| T5 | Timing side channel: verdict timing revealing packet contents | [CWE-385](https://cwe.mitre.org/data/definitions/385.html) | Fixed-latency verdict via a geometric delay line; timing is data-independent | `tb/test_l1_trigger.py::rejects_each_flag_with_identical_timing`; **formal** fixed-latency proof (`formal/l1_trigger.sby`) |

## Out of scope (documented, not defended)

- **UDP checksum verification** — requires the IP pseudo-header, which would break
  stage independence; the IP header checksum already protects routing-critical
  fields.
- **IP total-length vs. observed-length cross-check** — completes only at `tlast`,
  after the fixed-latency verdict must fire; a deliberate design tension.

## Reporting

Open a private security advisory on the repository, or contact the maintainer.
Please do not file public issues for undisclosed vulnerabilities.

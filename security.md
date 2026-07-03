# Security Model

## What we protect
The integrity of the accept/reject verdict, and the availability of the
pipeline, against a fully hostile input stream.

## Attacker model
The attacker controls every byte on the wire, forever. There is no
authentication upstream of this parser; it must survive arbitrary,
adversarially-chosen input indefinitely.

## Trust boundary
Every byte arriving on the AXI-Stream input is untrusted until each protocol
field has been explicitly validated. Nothing is assumed about length,
framing, or content.

## Threats, controls, and evidence

| ID | Threat | CWE | Control | Evidence |
|----|--------|-----|---------|----------|
| T1 | Wedge / DoS: truncated, oversized, or back-to-back garbage frames stall a stage | CWE-1245 | Every stage is stateless between frames and returns to idle on `tlast`; `tready` is never conditionally withheld | `test_fuzz.py` (asserts `tready` held + exactly one verdict per frame, 300 cases); `test_axis_skid.py` random-stall bench |
| T2 | Parser confusion: lying length fields, spoofed EtherType, forged IP checksum | CWE-20 | Validate version/IHL, EtherType, protocol, fragment flags, dest port, UDP length, and recompute the IP header checksum in hardware | `test_fuzz.py` golden-reference model (bad-accepts = 0 over valid/corrupted/random); directed `test_ipv4_parser.py` |
| T3 | Cross-packet leakage: one frame's bytes influencing the next frame's verdict | CWE-1272 | Fully stateless between packets; all match flags cleared at byte 0 of each frame | `test_l1_trigger.py` back-to-back verdicts; `test_fuzz.py` (300 frames streamed in sequence) |
| T4 | Uninitialized state after power-up or reset | CWE-1271 | Every flip-flop has a defined reset value; power-up state equals reset state | Synchronous reset branch in every `always_ff`; on-hardware bring-up (`fpga_top`) starts correctly with no explicit reset pulse |
| T5 | Timing side channel: verdict timing revealing packet contents | CWE-385 | Fixed-latency verdict via a geometric delay line; decision timing is data-independent | `test_l1_trigger.py::rejects_each_flag_with_identical_timing` (measured: accept and all reject cases land on the same cycle) |

## Out of scope (documented, not defended)
- UDP checksum verification (requires the IP pseudo-header, breaking stage
  independence; the IP checksum already protects routing-critical fields).
- IP total-length vs. observed-length cross-check (completes only at `tlast`,
  after the fixed-latency verdict must fire; a deliberate design tension).

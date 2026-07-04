# Formal proofs

SymbiYosys proofs, run with the OSS CAD Suite on PATH:

```bash
sby -f formal/axis_skid.sby     # AXI-Stream contract + single-slot + liveness
sby -f formal/l1_trigger.sby    # fixed-latency guarantee + no-bad-accept
```

Both complete by **k-induction** — the properties hold for all inputs and all
time, not merely within a bounded window. The SVA assertions live in the RTL
under `` `ifdef FORMAL `` (inactive for simulation and synthesis), so a proof
and its design never drift apart.

| Proof | Property |
|-------|----------|
| `axis_skid` | Output honours AXI-Stream (valid held, payload stable until accepted); never accepts while the skid slot is full; always drains when the consumer is ready. |
| `l1_trigger` | (1) **Fixed latency** — `verdict_valid` asserts exactly `LATENCY` cycles after its anchor event, for every input. (2) **No bad accept** — an accept verdict can only be emitted if every validation flag was high and the frame was not a runt; the pipeline can never manufacture an accept. |

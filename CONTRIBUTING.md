# Contributing

Thanks for your interest. This project keeps a high verification bar; the rules
below exist to protect it.

## Ground rules

- **CI is the gate.** Every push runs all cocotb benches, the fuzz campaign, and
  both formal proofs. A change merges only when CI is green. Do not disable a
  check to make it pass.
- **Test first.** New RTL behaviour arrives with a failing test that captures the
  contract, then the implementation that turns it green. A test you have never
  seen fail proves nothing.
- **One module per file**, file name equals module name. Every stage keeps the
  standard 10-pin AXI-Stream interface (`clk, rst_n, s_t*, m_t*`).
- **`always_ff` uses `<=`; `always_comb` uses `=`.** Every flip-flop has a reset
  branch. Size every literal (`8'hDE`, not `222`).

## Development loop

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

make -C tb DUT=<module>          # run one module's testbench
make -C tb DUT=<module> WAVES=1  # + dump waveforms for gtkwave
sby -f formal/<module>.sby       # run a formal proof (OSS CAD Suite on PATH)
```

## Adding a module

1. `rtl/<name>.sv` — synthesizable, standard interface, reset on every register.
2. `tb/test_<name>.py` — a cocotb bench; drive stimulus with scapy where a real
   packet is meaningful, and include the adversarial cases (truncated, malformed).
3. Add a `make -C tb DUT=<name>` step to `.github/workflows/sim.yml`.
4. Optional but encouraged: SVA properties under `` `ifdef FORMAL `` plus a
   `formal/<name>.sby`, wired into the `formal` CI job.

## Pull requests

Keep them focused — one logical change per PR. In the description, state the
contract the change satisfies and paste the passing test output (and, if you
touched timing-critical logic, the before/after WNS from `synth/char.tcl`).
Reviewers will ask you to justify anything they cannot derive from the diff.

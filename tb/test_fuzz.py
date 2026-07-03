# Adversarial fuzzing of parser_top against a Python golden reference model.
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from scapy.all import Ether, IP, UDP, Raw

MY_MAC   = "02:00:00:00:00:01"
MY_MAC_B = bytes([0x02, 0, 0, 0, 0, 0x01])
BCAST_B  = b"\xff" * 6
LISTEN   = 14310

def should_accept(w):
    if len(w) < 42:                              return False
    if w[0:6] != MY_MAC_B and w[0:6] != BCAST_B: return False
    if (w[12] << 8 | w[13]) != 0x0800:           return False
    if w[14] != 0x45:                            return False
    if (w[20] & 0x3F) or w[21]:                  return False
    if w[23] != 17:                              return False
    s = sum((w[i] << 8) | w[i + 1] for i in range(14, 34, 2))
    while s >> 16: s = (s & 0xFFFF) + (s >> 16)
    if s != 0xFFFF:                              return False
    if (w[36] << 8 | w[37]) != LISTEN:           return False
    if (w[38] << 8 | w[39]) < 8:                 return False
    return True

def valid_frame():
    return bytearray(bytes(Ether(dst=MY_MAC, src="02:00:00:00:00:02")
                     / IP(src="10.0.0.1", dst="10.0.0.2")
                     / UDP(sport=5000, dport=LISTEN) / Raw(b"payload!!")))

def make_case(rng):
    kind = rng.random()
    if kind < 0.35:
        return bytes(valid_frame())
    if kind < 0.75:
        w = valid_frame()
        for _ in range(rng.randint(1, 4)):
            w[rng.randrange(0, 42)] = rng.randrange(0, 256)
        return bytes(w)
    if kind < 0.9:
        return bytes(rng.randrange(0, 256) for _ in range(rng.randint(42, 60)))
    w = valid_frame()
    w[37] ^= 0xFF
    return bytes(w)

async def start(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.s_tvalid.value = 0
    dut.s_tlast.value = 0
    dut.m_tready.value = 1
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def run_frame(dut, wire):
    verdicts = []
    async def mon():
        while True:
            await FallingEdge(dut.clk)
            if int(dut.verdict_valid.value) == 1:
                verdicts.append(int(dut.verdict.value))
    h = cocotb.start_soon(mon())
    for i, b in enumerate(wire):
        dut.s_tdata.value  = b
        dut.s_tvalid.value = 1
        dut.s_tlast.value  = int(i == len(wire) - 1)
        assert int(dut.s_tready.value) == 1, "parser dropped tready -> wedge"
        await RisingEdge(dut.clk)
    dut.s_tvalid.value = 0
    dut.s_tlast.value = 0
    for _ in range(12): await RisingEdge(dut.clk)
    h.kill()
    return verdicts

@cocotb.test()
async def fuzz_matches_reference(dut):
    await start(dut)
    rng = random.Random(0xC0FFEE)
    bad_accepts = 0
    for n in range(300):
        wire = make_case(rng)
        got  = await run_frame(dut, wire)
        exp  = should_accept(wire)
        assert len(got) == 1, f"case {n}: expected 1 verdict, got {got} (wedge/dup)"
        if got[0] == 1 and not exp: bad_accepts += 1
        assert got[0] == int(exp), \
            f"case {n}: hw={got[0]} ref={int(exp)} len={len(wire)} wire={wire.hex()}"
    dut._log.info(f"300 fuzz cases matched reference; bad-accepts={bad_accepts}")

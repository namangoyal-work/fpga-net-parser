import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

LATENCY = 4          # must match the RTL parameter default


def set_flags(dut, mac, typ, ip, udp):
    dut.mac_ok.value  = mac
    dut.type_ok.value = typ
    dut.ip_ok.value   = ip
    dut.udp_ok.value  = udp


async def start(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.s_tvalid.value = 0
    dut.s_tlast.value = 0
    dut.m_tready.value = 1
    set_flags(dut, 0, 0, 0, 0)
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def send_and_time(dut, n_bytes):
    """Send an n-byte frame; return (falling edges until verdict_valid, verdict)."""
    for i in range(n_bytes):
        dut.s_tdata.value  = i & 0xFF
        dut.s_tvalid.value = 1
        dut.s_tlast.value  = int(i == n_bytes - 1)
        await RisingEdge(dut.clk)          # the last of these is the anchor edge
    dut.s_tvalid.value = 0
    dut.s_tlast.value  = 0
    k = 0
    while True:
        await FallingEdge(dut.clk)
        k += 1
        if int(dut.verdict_valid.value) == 1:
            return k, int(dut.verdict.value)
        assert k < LATENCY + 10, "verdict never arrived (wedged trigger)"


@cocotb.test()
async def accepts_and_is_punctual(dut):
    await start(dut)
    set_flags(dut, 1, 1, 1, 1)
    k, v = await send_and_time(dut, 40)
    assert v == 1, "all flags high must accept"
    assert k == LATENCY, f"verdict at {k} cycles, expected exactly {LATENCY}"


@cocotb.test()
async def rejects_each_flag_with_identical_timing(dut):
    await start(dut)
    for missing in range(4):
        flags = [1, 1, 1, 1]
        flags[missing] = 0
        set_flags(dut, *flags)
        k, v = await send_and_time(dut, 40)
        assert v == 0, f"flag {missing} low must reject"
        assert k == LATENCY, \
            f"reject timing {k} != {LATENCY}: verdict timing must not depend on contents"
        for _ in range(3):
            await RisingEdge(dut.clk)


@cocotb.test()
async def runt_frame_rejected_deterministically(dut):
    await start(dut)
    set_flags(dut, 1, 1, 1, 1)                 # flags lie 'accept' - runt must override
    k, v = await send_and_time(dut, 20)
    assert v == 0, "runt frame must be rejected regardless of flags"
    assert k == LATENCY, f"runt verdict at {k}, expected exactly {LATENCY} after tlast"


@cocotb.test()
async def back_to_back_frames_get_separate_verdicts(dut):
    await start(dut)
    set_flags(dut, 1, 1, 1, 1)
    pulses = []

    async def monitor():
        t = 0
        while True:
            await FallingEdge(dut.clk)
            t += 1
            if int(dut.verdict_valid.value) == 1:
                pulses.append((t, int(dut.verdict.value)))

    cocotb.start_soon(monitor())
    for _ in range(2):                          # two 40-byte frames, zero gap
        for i in range(40):
            dut.s_tdata.value  = i & 0xFF
            dut.s_tvalid.value = 1
            dut.s_tlast.value  = int(i == 39)
            await RisingEdge(dut.clk)
    dut.s_tvalid.value = 0
    dut.s_tlast.value  = 0
    for _ in range(LATENCY + 4):
        await RisingEdge(dut.clk)
    assert len(pulses) == 2, f"expected 2 verdict pulses, got {len(pulses)}"
    assert pulses[1][0] - pulses[0][0] == 40, "verdicts must be exactly one frame apart"
    assert pulses[0][1] == 1 and pulses[1][1] == 1

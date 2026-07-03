import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from scapy.all import Ether, IP, UDP, Raw

MY_MAC = "02:00:00:00:00:01"
SRC    = "02:00:00:00:00:02"
LISTEN = 14310


def frame(dport=LISTEN, sport=5000, payload=b"hello"):
    return bytes(Ether(dst=MY_MAC, src=SRC)
                 / IP(src="10.0.0.1", dst="10.0.0.2")
                 / UDP(sport=sport, dport=dport) / Raw(payload))


async def start(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.s_tvalid.value = 0
    dut.m_tready.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def send_frame(dut, wire):
    for i, b in enumerate(wire):
        dut.s_tdata.value  = b
        dut.s_tvalid.value = 1
        dut.s_tlast.value  = int(i == len(wire) - 1)
        await RisingEdge(dut.clk)
    dut.s_tvalid.value = 0
    dut.s_tlast.value  = 0
    for _ in range(3):
        await RisingEdge(dut.clk)


@cocotb.test()
async def accepts_listen_port(dut):
    await start(dut)
    payload = b"hello"
    await send_frame(dut, frame(payload=payload))
    assert int(dut.udp_done.value) == 1, "UDP header must complete"
    assert int(dut.udp_ok.value) == 1,   "our port must be accepted"
    assert int(dut.src_port.value) == 5000
    assert int(dut.dst_port.value) == LISTEN
    assert int(dut.udp_len.value) == 8 + len(payload)


@cocotb.test()
async def rejects_wrong_port(dut):
    await start(dut)
    await send_frame(dut, frame(dport=9999))
    assert int(dut.udp_done.value) == 1, "parser must complete before rejecting"
    assert int(dut.udp_ok.value) == 0,   "stranger's port must be rejected"


@cocotb.test()
async def rejects_impossible_length(dut):
    await start(dut)
    bad = bytearray(frame())
    bad[38] = 0x00
    bad[39] = 0x05                      # claims 5 bytes: less than its own header
    await send_frame(dut, bytes(bad))
    assert int(dut.udp_done.value) == 1, "parser must complete before rejecting"
    assert int(dut.udp_ok.value) == 0,   "length < 8 must be rejected"


@cocotb.test()
async def truncated_then_recovers(dut):
    await start(dut)
    wire = frame()
    await send_frame(dut, wire[:38])    # dies mid-UDP-header
    assert int(dut.udp_done.value) == 0, "truncated header must not complete"
    await send_frame(dut, wire)
    assert int(dut.udp_ok.value) == 1,   "parser must recover after truncation"

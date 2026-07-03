import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from scapy.all import Ether, IP, UDP, Raw

MY_MAC = "02:00:00:00:00:01"
SRC    = "02:00:00:00:00:02"


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
async def accepts_frame_for_us(dut):
    await start(dut)
    wire = bytes(Ether(dst=MY_MAC, src=SRC) / IP() / UDP() / Raw(b"hello"))
    await send_frame(dut, wire)
    assert int(dut.hdr_done.value) == 1, "header should be complete"
    assert int(dut.mac_ok.value) == 1,  "our MAC must be accepted"
    assert int(dut.type_ok.value) == 1, "IPv4 EtherType must be accepted"

@cocotb.test()
async def rejects_wrong_mac(dut):
    await start(dut)
    wire = bytes(Ether(dst="02:00:00:00:00:99", src=SRC) / IP() / UDP() / Raw(b"hello"))
    await send_frame(dut, wire)
    assert int(dut.mac_ok.value) == 0,  "stranger's MAC must be rejected"
    assert int(dut.type_ok.value) == 1


@cocotb.test()
async def accepts_broadcast(dut):
    await start(dut)
    wire = bytes(Ether(dst="ff:ff:ff:ff:ff:ff", src=SRC) / IP() / UDP() / Raw(b"hello"))
    await send_frame(dut, wire)
    assert int(dut.mac_ok.value) == 1, "broadcast must be accepted"


@cocotb.test()
async def rejects_wrong_ethertype(dut):
    await start(dut)
    wire = bytes(Ether(dst=MY_MAC, src=SRC, type=0x86DD) / Raw(bytes(30)))
    await send_frame(dut, wire)
    assert int(dut.mac_ok.value) == 1
    assert int(dut.type_ok.value) == 0, "non-IPv4 EtherType must be rejected"


@cocotb.test()
async def truncated_frame_then_recovery(dut):
    await start(dut)
    wire = bytes(Ether(dst=MY_MAC, src=SRC) / IP() / UDP() / Raw(b"hello"))
    await send_frame(dut, wire[:8])          # dies mid-MAC, tlast fires early
    assert int(dut.hdr_done.value) == 0, "truncated frame must not complete"
    await send_frame(dut, wire)              # full frame right after
    assert int(dut.mac_ok.value) == 1,  "parser must recover after truncation"
    assert int(dut.type_ok.value) == 1

import socket
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from scapy.all import Ether, IP, UDP, Raw

MY_MAC = "02:00:00:00:00:01"
SRC    = "02:00:00:00:00:02"


def ip_int(dotted):
    return int.from_bytes(socket.inet_aton(dotted), "big")


def good_frame():
    return bytes(Ether(dst=MY_MAC, src=SRC)
                 / IP(src="10.0.0.1", dst="10.0.0.2")
                 / UDP(sport=5000, dport=14310) / Raw(b"hello"))


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
async def accepts_valid_ipv4(dut):
    await start(dut)
    wire = good_frame()
    await send_frame(dut, wire)
    assert int(dut.ip_done.value) == 1, "header should be complete"
    assert int(dut.ip_ok.value) == 1,   "pristine IPv4 header must be accepted"
    assert int(dut.src_ip.value) == ip_int("10.0.0.1")
    assert int(dut.dst_ip.value) == ip_int("10.0.0.2")
    assert int(dut.total_len.value) == len(wire) - 14


@cocotb.test()
async def rejects_corrupted_checksum(dut):
    await start(dut)
    bad = bytearray(good_frame())
    bad[18] ^= 0x01                     # flip one bit in the identification field
    await send_frame(dut, bytes(bad))
    assert int (dut.ip_done.value) == 1
    assert int(dut.ip_ok.value) == 0, "single flipped bit must be caught by checksum"


@cocotb.test()
async def rejects_wrong_version_ihl(dut):
    await start(dut)
    bad = bytearray(good_frame())
    bad[14] = 0x46                      # IHL = 6: header with options
    await send_frame(dut, bytes(bad))
    assert int(dut.ip_done.value) == 1
    assert int(dut.ip_ok.value) == 0, "IHL != 5 must be rejected"


@cocotb.test()
async def rejects_fragments(dut):
    await start(dut)
    wire = bytes(Ether(dst=MY_MAC, src=SRC)
                 / IP(src="10.0.0.1", dst="10.0.0.2", flags="MF")
                 / UDP() / Raw(b"hello"))
    await send_frame(dut, wire)
    assert int (dut.ip_done.value) == 1
    assert int(dut.ip_ok.value) == 0, "fragmented packet must be rejected"


@cocotb.test()
async def rejects_non_udp(dut):
    await start(dut)
    wire = bytes(Ether(dst=MY_MAC, src=SRC)
                 / IP(src="10.0.0.1", dst="10.0.0.2", proto=6)
                 / Raw(bytes(20)))
    await send_frame(dut, wire)
    assert int (dut.ip_done.value) == 1 
    assert int(dut.ip_ok.value) == 0, "TCP must be rejected"


@cocotb.test()
async def truncated_then_recovers(dut):
    await start(dut)
    wire = good_frame()
    await send_frame(dut, wire[:20])    # dies mid-IP-header
    assert int(dut.ip_done.value) == 0, "truncated header must not complete"
    await send_frame(dut, wire)
    assert int(dut.ip_done.value) == 1
    assert int(dut.ip_ok.value) == 1,   "parser must recover after truncation"

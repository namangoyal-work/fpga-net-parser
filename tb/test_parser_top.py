import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from scapy.all import Ether, IP, UDP, Raw

MY_MAC = "02:00:00:00:00:01"
SRC = "02:00:00:00:00:02"
LISTEN = 14310

def frame(dst=MY_MAC, dport=LISTEN):
    return bytes(Ether(dst=dst, src=SRC)/IP(src="10.0.0.1", dst="10.0.0.2")
                 /UDP(sport=5000, dport=dport)/Raw(b"hello world"))

async def start(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value=0; dut.s_tvalid.value=0; dut.s_tlast.value=0; dut.m_tready.value=1
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value=1; await RisingEdge(dut.clk)

async def run(dut, wires):
    verdicts=[]
    async def mon():
        while True:
            await FallingEdge(dut.clk)
            if int(dut.verdict_valid.value)==1:
                verdicts.append(int(dut.verdict.value))
    h=cocotb.start_soon(mon())
    for wire in wires:
        for i,b in enumerate(wire):
            dut.s_tdata.value=b; dut.s_tvalid.value=1; dut.s_tlast.value=int(i==len(wire)-1)
            await RisingEdge(dut.clk)
    dut.s_tvalid.value=0; dut.s_tlast.value=0
    for _ in range(12): await RisingEdge(dut.clk)
    h.kill()
    return verdicts

@cocotb.test()
async def accept(dut):
    await start(dut); v=await run(dut,[frame()])
    assert v==[1], f"valid frame must accept, got {v}"

@cocotb.test()
async def reject_mac(dut):
    await start(dut); v=await run(dut,[frame(dst="02:00:00:00:00:99")])
    assert v==[0], f"wrong MAC must reject, got {v}"

@cocotb.test()
async def reject_port(dut):
    await start(dut); v=await run(dut,[frame(dport=9999)])
    assert v==[0], f"wrong port must reject, got {v}"

@cocotb.test()
async def back_to_back(dut):
    await start(dut); v=await run(dut,[frame(),frame()])
    assert v==[1,1], f"two valid frames must give two accepts, got {v}"

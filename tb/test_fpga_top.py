import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

async def boot(dut, sw):
    cocotb.start_soon(Clock(dut.CLK100MHZ, 10, unit="ns").start())
    dut.sw.value = sw
    dut.btn.value = 1
    for _ in range(3): await RisingEdge(dut.CLK100MHZ)
    dut.btn.value = 0
    for _ in range(220): await RisingEdge(dut.CLK100MHZ)

@cocotb.test()
async def accept_when_switch_low(dut):
    await boot(dut, 0)
    assert dut.led.value.integer & 1 == 1, "led[0] must be ON (accept)"

@cocotb.test()
async def reject_when_switch_high(dut):
    await boot(dut, 1)
    assert dut.led.value.integer & 1 == 0, "led[0] must be OFF (reject)"

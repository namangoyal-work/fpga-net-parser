import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def belt_passes_bytes_unchanged(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    dut.m_tready.value = 1

    data = [0xDE, 0xAD, 0xBE, 0xEF]
    for i, b in enumerate(data):
        dut.s_tdata.value = b
        dut.s_tvalid.value = 1
        dut.s_tlast.value = int(i == len(data) - 1)
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        assert dut.m_tdata.value == b, \
            f"m_tdata={int(dut.m_tdata.value):#x}, expected {b:#x}"
        assert dut.m_tvalid.value == 1
        assert dut.m_tlast.value == int(i == len(data) - 1)

    dut.s_tvalid.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.m_tvalid.value == 0

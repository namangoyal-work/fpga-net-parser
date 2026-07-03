import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Event, with_timeout

async def reset(dut):
    dut.rst_n.value = 0
    dut.s_tvalid.value = 0
    dut.m_tready.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1


async def consumer(dut):          # the chaos generator — free of charge
    while True:
        await RisingEdge(dut.clk)
        dut.m_tready.value = random.randint(0, 1)


async def driver(dut, scoreboard, n_bytes=200):

    for i in range(n_bytes):
        byte = random.randint(0, 255)
        last = int(i % 20 == 19)

        dut.s_tdata.value  = byte
        dut.s_tvalid.value = 1
        dut.s_tlast.value  = last
        scoreboard.append((byte, last))
        while True:
            await FallingEdge(dut.clk)
            if int(dut.s_tready.value) == 1:
                break                          # both high mid-cycle -> transfer
                                               # completes at the NEXT rising edge

        await RisingEdge(dut.clk)              # hold everything through that edge!
                                               # only now may inputs change (rule 1)
        if random.random() < 0.2:              # occasional idle gap between bytes
            dut.s_tvalid.value = 0
            dut.s_tlast.value  = 0
            for _ in range(random.randint(1, 3)):
                await RisingEdge(dut.clk)

    dut.s_tvalid.value = 0                     # go quiet when done, and stay quiet
    dut.s_tlast.value  = 0



async def checker(dut, scoreboard, done, expected_total):
    count = 0
    while True:
        await FallingEdge(dut.clk)
        if int(dut.m_tvalid.value) == 1 and int(dut.m_tready.value) == 1:
            assert scoreboard, \
                f"beat #{count}: output fired but scoreboard is empty -> DUPLICATION"
            exp_byte, exp_last = scoreboard.pop(0)
            got_byte = int(dut.m_tdata.value)
            got_last = int(dut.m_tlast.value)
            assert got_byte == exp_byte, \
                f"beat #{count}: got {got_byte:#04x}, expected {exp_byte:#04x}"
            assert got_last == exp_last, \
                f"beat #{count}: tlast={got_last}, expected {exp_last}"
            count += 1
            if count == expected_total:
                done.set()
                return


@cocotb.test()
async def skid_survives_random_stalls(dut):
        cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
        await reset(dut)

        N = 200
        scoreboard = []
        done = Event()

        cocotb.start_soon(consumer(dut))
        cocotb.start_soon(driver(dut, scoreboard, n_bytes=N))
        cocotb.start_soon(checker(dut, scoreboard, done, expected_total=N))

        await with_timeout(done.wait(), 100_000, "ns")      # wedge detector: fail loudly, don't hang
        assert not scoreboard, f"{len(scoreboard)} bytes never emerged -> DROPPED"


# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    
    # set the clock period to 40ns (25 MHz for VGA)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    # assert reset 
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    dut._log.info("Test VGA Pong")
    
    # wait a bit for the game to initialize
    await ClockCycles(dut.clk, 100)
    
    # check that HSYNC and VSYNC are toggling (bits 0 and 1 of uo_out)
    hsync_values = set()
    vsync_values = set()
    
    for _ in range(1000):
        await ClockCycles(dut.clk, 1)
        output = int(dut.uo_out.value)
        hsync_values.add(output & 0x01)  # bit 0
        vsync_values.add((output >> 1) & 0x01)  # bit 1
    
    # HSYNC and VSYNC should both toggle between 0 and 1
    assert len(hsync_values) == 2, f"HSYNC should toggle, got values: {hsync_values}"
    assert len(vsync_values) == 2, f"VSYNC should toggle, got values: {vsync_values}"
    
    dut._log.info("Test paddle controls")
    
    # press up button
    dut.ui_in.value = 0x01
    await ClockCycles(dut.clk, 10000)  # wait for paddle to move
    
    # press down button
    dut.ui_in.value = 0x02
    await ClockCycles(dut.clk, 10000)
    
    # release buttons
    dut.ui_in.value = 0x00
    await ClockCycles(dut.clk, 1000)
    
    dut._log.info("Pong test passed!")

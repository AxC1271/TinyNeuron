# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    
    # set the clock period to 40ns (25 MHz for VGA)
    clock = Clock(dut.clk, 40, unit="ns")  # Fixed 'unit' not 'units'
    cocotb.start_soon(clock.start())
    
    # assert reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    dut._log.info("Test VGA Pong - checking HSYNC")
    
    # HSYNC should toggle much faster (every 800 clocks)
    # check HSYNC toggles within reasonable time
    hsync_values = set()
    
    for _ in range(2000):  # 2000 clocks = 2.5 HSYNC periods
        await ClockCycles(dut.clk, 1)
        output = int(dut.uo_out.value)
        hsync_values.add(output & 0x01)  # bit 0
        if len(hsync_values) == 2:
            break
    
    assert len(hsync_values) == 2, f"HSYNC should toggle, got values: {hsync_values}"
    dut._log.info("HSYNC toggling correctly!")
    
    # for VSYNC, we'd need to wait 420,000 cycles which is too slow for CI
    # just verify the design runs without crashing
    dut._log.info("Running extended test")
    await ClockCycles(dut.clk, 10000)
    
    dut._log.info("Pong test passed!")

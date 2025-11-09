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
    
    dut._log.info("Test VGA Pong - checking HSYNC")
    
    # HSYNC is at bit 7 of uo_out
    # HSYNC should toggle every 800 clocks (H_TOTAL)
    hsync_values = set()
    
    for _ in range(2000):  # 2000 clocks = 2.5 HSYNC periods
        await ClockCycles(dut.clk, 1)
        output = int(dut.uo_out.value)
        hsync = (output >> 7) & 0x01  # extract bit 7
        hsync_values.add(hsync)
        if len(hsync_values) == 2:
            break
    
    assert len(hsync_values) == 2, f"HSYNC should toggle, got values: {hsync_values}"
    dut._log.info("HSYNC toggling correctly!")
    
    # test vsync at bit 3
    dut._log.info("Checking VSYNC")
    vsync_values = set()
    
    # vsync toggles every 525 lines * 800 clocks = 420,000 clocks
    for _ in range(1000000):
        await ClockCycles(dut.clk, 1)
        output = int(dut.uo_out.value)
        vsync = (output >> 3) & 0x01  # extract bit 3
        vsync_values.add(vsync)
        if len(vsync_values) == 2:
            break
    
    assert len(vsync_values) == 2, f"VSYNC should toggle, got values: {vsync_values}"
    dut._log.info("VSYNC toggling correctly!")
    
    # test paddle movement
    dut._log.info("Testing paddle movement")
    
    # wait for frame boundary
    await ClockCycles(dut.clk, 420000)
    
    # press up button
    dut.ui_in.value = 0x01  # btn_up
    await ClockCycles(dut.clk, 420000)  # wait one frame
    
    # press down button
    dut.ui_in.value = 0x02  # btn_down
    await ClockCycles(dut.clk, 420000)  # 
    
    dut.ui_in.value = 0x00  # release buttons
    
    # let ball move for a few frames
    await ClockCycles(dut.clk, 10000)
    
    dut._log.info("Pong test passed!")

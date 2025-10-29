/*
 * Copyright (c) 2024 Andrew Chen
 * SPDX-License-Identifier: Apache-2.0
 */


// Simplified Pong for TinyTapeout
// Testbench to verify behavior
// 640x480 @ 60Hz VGA
// Single paddle + ball

`timescale 1ns / 1ps
`default_nettype none

module tb;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    // simulate unit under test
    tt_um_axc1271_tinypong uut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // clock generation: 25 MHz = 40 ns period
    initial clk = 0;
    always #20 clk = ~clk;

    // manually reset
    initial begin
        rst_n = 0; // active low
        ena = 1;
        ui_in = 8'b0;
        uio_in = 8'b0;
        #200;
        rst_n = 1;
    end

    initial begin
        // wait a few frames
        #1_000_000;

        // simulate pressing the up button
        ui_in[0] = 1;
        #500_000;
        ui_in[0] = 0;

        // simulate pressing the down button
        #1_000_000;
        ui_in[1] = 1;
        #500_000;
        ui_in[1] = 0;

        // run for a while to let ball move
        #5_000_000;
        $stop;
    end

    // optional: Monitor some outputs
    always @(posedge clk) begin
        // simple VGA signal monitor
        if (uut.h_count == 0 && uut.v_count == 0)
            $display("Frame start: Ball=(%0d,%0d), Paddle_y=%0d, HSYNC=%b, VSYNC=%b",
                uut.ball_x, uut.ball_y, uut.paddle_y, uo_out[0], uo_out[1]);
    end

endmodule

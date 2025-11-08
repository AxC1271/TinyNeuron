`timescale 1ns / 1ps

/*
 * Copyright (c) 2024 Andrew Chen
 * SPDX-License-Identifier: Apache-2.0
 */

// Simplified Pong for TinyTapeout
// 640x480 @ 60Hz VGA
// Single paddle + ball

`default_nettype none

module tt_um_axc1271_tinypong (
    input  wire [7:0] ui_in,    // ui_in[0]=up, ui_in[1]=down
    output wire [7:0] uo_out,   // VGA output
    input  wire [7:0] uio_in,   // Unused
    output wire [7:0] uio_out,  // Unused
    output wire [7:0] uio_oe,   // Unused
    input  wire       ena,      // Unused
    input  wire       clk,      // 25 MHz for VGA
    input  wire       rst_n
);

    // VGA parameters
    localparam H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48, H_TOTAL = 800;
    localparam V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2,  V_BACK = 33, V_TOTAL = 525;

    // horizontal/vertical counters
    reg [9:0] h_count;
    reg [9:0] v_count;

    wire hsync = (h_count >= (H_VISIBLE + H_FRONT)) && (h_count < (H_VISIBLE + H_FRONT + H_SYNC));
    wire vsync = (v_count >= (V_VISIBLE + V_FRONT)) && (v_count < (V_VISIBLE + V_FRONT + V_SYNC));
    wire video_active = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    wire [9:0] x = h_count;
    wire [9:0] y = v_count;

    // horizontal counter
    always @(posedge clk) begin
        if (!rst_n) h_count <= 0;
        else h_count <= (h_count == H_TOTAL-1) ? 0 : h_count + 1;
    end

    // vertical counter
    always @(posedge clk) begin
        if (!rst_n) v_count <= 0;
        else if (h_count == H_TOTAL-1)
            v_count <= (v_count == V_TOTAL-1) ? 0 : v_count + 1;
    end

    // buttons
    wire btn_up   = ui_in[0];
    wire btn_down = ui_in[1];

    // paddle
    localparam PADDLE_X = 20;
    localparam PADDLE_WIDTH = 8;
    localparam PADDLE_HEIGHT = 60;
    reg [8:0] paddle_y;

    always @(posedge clk) begin
        if (!rst_n) paddle_y <= 240 - PADDLE_HEIGHT/2;
        else if (h_count == 0 && v_count == 0) begin
            if (btn_up)
                paddle_y <= (paddle_y >= 4) ? paddle_y - 4 : 0;
            else if (btn_down)
                paddle_y <= (paddle_y + 4 <= V_VISIBLE - PADDLE_HEIGHT) ? paddle_y + 4 : V_VISIBLE - PADDLE_HEIGHT;
        end
    end

    // ball
    localparam BALL_SIZE = 10;
    reg [9:0] ball_x;
    reg [8:0] ball_y;
    reg signed [3:0] ball_dx;
    reg signed [3:0] ball_dy;

    // next position/delta (wide signed to prevent wraparound)
    reg signed [14:0] next_ball_x;
    reg signed [13:0] next_ball_y;
    reg signed [3:0]  next_ball_dx;
    reg signed [3:0]  next_ball_dy;

    always @(posedge clk) begin
        if (!rst_n) begin
            ball_x <= 320;
            ball_y <= 240;
            ball_dx <= -5;
            ball_dy <= -5;
        end else if (h_count == 0 && v_count == 0) begin
            // safe signed addition
            next_ball_x  = $signed({5'b0, ball_x}) + $signed(ball_dx);
            next_ball_y  = $signed({4'b0, ball_y}) + $signed(ball_dy);
            next_ball_dx = ball_dx;
            next_ball_dy = ball_dy;

            // top/bottom walls
            if (next_ball_y <= 0) begin
                next_ball_dy = -ball_dy;
                next_ball_y  = 0;
            end else if (next_ball_y >= V_VISIBLE - BALL_SIZE) begin
                next_ball_dy = -ball_dy;
                next_ball_y  = V_VISIBLE - BALL_SIZE;
            end

            // left/right walls
            if (next_ball_x >= H_VISIBLE - BALL_SIZE) begin
                next_ball_dx = -ball_dx;
                next_ball_x  = H_VISIBLE - BALL_SIZE;
            end

            // paddle collision (left side)
            if ((next_ball_x <= PADDLE_X + PADDLE_WIDTH) &&
                (ball_x > PADDLE_X) &&
                (next_ball_y + BALL_SIZE > paddle_y) &&
                (next_ball_y < paddle_y + PADDLE_HEIGHT)) begin

                next_ball_dx = -ball_dx;
                next_ball_x  = PADDLE_X + PADDLE_WIDTH;
            end

            // missed paddle -> reset
            if (next_ball_x <= 0) begin
                ball_x  <= 320;
                ball_y  <= 240;
                ball_dx <= 5;
                ball_dy <= 5;
            end else begin
                ball_x  <= next_ball_x[9:0];
                ball_y  <= next_ball_y[8:0];
                ball_dx <= next_ball_dx;
                ball_dy <= next_ball_dy;
            end
        end
    end

    // rendering
    wire in_paddle      = (x >= PADDLE_X) && (x < PADDLE_X + PADDLE_WIDTH) &&
                          (y >= paddle_y) && (y < paddle_y + PADDLE_HEIGHT);

    wire in_ball        = (x >= ball_x) && (x < ball_x + BALL_SIZE) &&
                          (y >= ball_y) && (y < ball_y + BALL_SIZE);

    wire in_center_line = (x >= 318 && x <= 322) && (y[4] == 0);

    wire [1:0] red   = in_paddle ? 2'b11 : (in_ball ? 2'b11 : 2'b00);
    wire [1:0] green = in_paddle ? 2'b11 : (in_ball ? 2'b11 : (in_center_line ? 2'b10 : 2'b00));
    wire [1:0] blue  = in_paddle ? 2'b11 : (in_ball ? 2'b11 : 2'b00);

    wire [1:0] out_red   = video_active ? red   : 2'b00;
    wire [1:0] out_green = video_active ? green : 2'b00;
    wire [1:0] out_blue  = video_active ? blue  : 2'b00;

    assign uo_out = {out_blue, out_green, out_red, vsync, hsync};
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    wire _unused = &{ena, uio_in, ui_in[7:2], 1'b0};

endmodule

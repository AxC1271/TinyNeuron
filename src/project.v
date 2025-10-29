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
    output wire [7:0] uio_oe,   // IO direction
    input  wire       ena,
    input  wire       clk,      // 25 MHz for VGA
    input  wire       rst_n
);

    // define VGA constraints here
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;
    
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;
    
    reg [9:0] h_count;
    reg [9:0] v_count;
    
    wire hsync = (h_count >= (H_VISIBLE + H_FRONT)) && 
                 (h_count < (H_VISIBLE + H_FRONT + H_SYNC));
    wire vsync = (v_count >= (V_VISIBLE + V_FRONT)) && 
                 (v_count < (V_VISIBLE + V_FRONT + V_SYNC));
    
    wire video_active = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    wire [9:0] x = h_count;
    wire [9:0] y = v_count;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            h_count <= 0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                if (v_count == V_TOTAL - 1) begin
                    v_count <= 0;
                end else begin
                    v_count <= v_count + 1;
                end
            end
        end
    end
    

    // define simple button debouncing here
    wire btn_up_raw = ui_in[0];
    wire btn_down_raw = ui_in[1];
    
    // simple debounce: sample every N frames
    reg [3:0] debounce_counter;
    reg btn_up, btn_down;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            debounce_counter <= 0;
            btn_up <= 0;
            btn_down <= 0;
        end else begin
            // sample buttons at start of frame
            if (h_count == 0 && v_count == 0) begin
                if (debounce_counter == 15) begin
                    btn_up <= btn_up_raw;
                    btn_down <= btn_down_raw;
                    debounce_counter <= 0;
                end else begin
                    debounce_counter <= debounce_counter + 1;
                end
            end
        end
    end
    
    // paddle (left side)
    localparam PADDLE_X = 20;
    localparam PADDLE_WIDTH = 8;
    localparam PADDLE_HEIGHT = 60;
    reg [8:0] paddle_y;  // 0-479
    
    // ball
    localparam BALL_SIZE = 8;
    reg [9:0] ball_x;  // 0-639
    reg [8:0] ball_y;  // 0-479
    reg signed [2:0] ball_dx;
    reg signed [2:0] ball_dy;  
    
    // speed control (update every N frames)
    reg [2:0] speed_counter;

    // process controls paddle hit
    always @(posedge clk) begin
        if (!rst_n) begin
            paddle_y <= 240 - PADDLE_HEIGHT/2;  // center
        end else begin
            // Update once per frame
            if (h_count == 0 && v_count == 0) begin
                if (btn_up && paddle_y > 0) begin
                    paddle_y <= paddle_y - 3;
                end else if (btn_down && paddle_y < (480 - PADDLE_HEIGHT)) begin
                    paddle_y <= paddle_y + 3;
                end
            end
        end
    end
    
    // physics for pong ball
    always @(posedge clk) begin
        if (!rst_n) begin
            ball_x <= 320;  
            ball_y <= 240;  
            ball_dx <= 2;   
            ball_dy <= 1;   
            speed_counter <= 0;
        end else begin
            // update ball position every 2 frames (slow it down)
            if (h_count == 0 && v_count == 0) begin
                if (speed_counter == 1) begin
                    speed_counter <= 0;
                    
                    // move ball
                    ball_x <= ball_x + {{7{ball_dx[2]}}, ball_dx};  
                    ball_y <= ball_y + {{6{ball_dy[2]}}, ball_dy};
                    
                    // if we have collision with top/bottom walls, flip dy
                    if (ball_y <= 0 || ball_y >= (480 - BALL_SIZE)) begin
                        ball_dy <= -ball_dy;
                    end
                    
                    // collision with paddle should flip dx
                    if (ball_x <= (PADDLE_X + PADDLE_WIDTH) && 
                        ball_x >= PADDLE_X &&
                        ball_y >= paddle_y && 
                        ball_y <= (paddle_y + PADDLE_HEIGHT)) begin
                        ball_dx <= -ball_dx;
                        
                        // add spin based on where ball hit paddle
                        if (ball_y < (paddle_y + PADDLE_HEIGHT/3)) begin
                            ball_dy <= -2;  // hit top → bounce up
                        end else if (ball_y > (paddle_y + 2*PADDLE_HEIGHT/3)) begin
                            ball_dy <= 2;   // hit bottom → bounce down
                        end else begin
                            ball_dy <= 0;   // hit middle → straight
                        end
                    end
                    
                    // ball went off right side → reset
                    if (ball_x >= 640) begin
                        ball_x <= 320;
                        ball_y <= 240;
                        ball_dx <= 2;
                        ball_dy <= 1;
                    end
                    
                    // ball hit left wall → reset
                    if (ball_x <= 0) begin
                        ball_x <= 320;
                        ball_y <= 240;
                        ball_dx <= 2;
                        ball_dy <= 1;
                    end
                    
                end else begin
                    speed_counter <= speed_counter + 1;
                end
            end
        end
    end
    
    // here we handle visual rendering
    
    // check if current pixel is part of paddle
    wire in_paddle = (x >= PADDLE_X) && 
                     (x < (PADDLE_X + PADDLE_WIDTH)) &&
                     (y >= paddle_y) && 
                     (y < (paddle_y + PADDLE_HEIGHT));
    
    // check if current pixel is part of ball
    wire in_ball = (x >= ball_x) && 
                   (x < (ball_x + BALL_SIZE)) &&
                   (y >= ball_y) && 
                   (y < (ball_y + BALL_SIZE));
    
    wire in_center_line = (x >= 318 && x <= 322) && (y[4] == 0);
    
    // colors (2 bits per channel due to constraints)
    wire [1:0] red, green, blue;
    
    assign red   = in_paddle ? 2'b11 : (in_ball ? 2'b11 : 2'b00);
    assign green = in_paddle ? 2'b11 : (in_ball ? 2'b11 : (in_center_line ? 2'b10 : 2'b00));
    assign blue  = in_paddle ? 2'b11 : (in_ball ? 2'b11 : 2'b00);
    
    // output (blank when not in active video)
    wire [1:0] out_red   = video_active ? red   : 2'b00;
    wire [1:0] out_green = video_active ? green : 2'b00;
    wire [1:0] out_blue  = video_active ? blue  : 2'b00;
    
    // we do our final pin assignments here
    assign uo_out = {
        out_blue,   // [7:6]
        out_green,  // [5:4]
        out_red,    // [3:2]
        vsync,      // [1]
        hsync       // [0]
    };
    
    assign uio_out = 8'h00;
    assign uio_oe = 8'h00;
    
    wire _unused = &{ena, uio_in, ui_in[7:2], 1'b0};

endmodule


// Requirements:
// 
// Clock: 25.175 MHz (can use 25 MHz, close enough)
//
// Connections:
//   ui_in[0] → up button   (active high)
//   ui_in[1] → down button (active high)
//   
//   uo_out[0] → VGA HSYNC (pin 13)
//   uo_out[1] → VGA VSYNC (pin 14)
//   uo_out[3:2] → RED DAC → VGA RED (pin 1)
//   uo_out[5:4] → GREEN DAC → VGA GREEN (pin 2)
//   uo_out[7:6] → BLUE DAC → VGA BLUE (pin 3)
//
// Resistor DAC per color channel:
//   Bit[1] ──[270Ω]──┬─── VGA Color Pin
//   Bit[0] ──[560Ω]──┘
//
// Features:
//   - Left paddle controlled by up/down buttons
//   - Ball bounces off paddle, walls, and top/bottom
//   - Ball resets when it goes off screen
//   - Center dashed line
//   - Simple physics with spin based on paddle hit location

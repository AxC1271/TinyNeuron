`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  tt_um_axc1271_tinypong uut (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
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

    // optional: monitor some outputs
    // always @(posedge clk) begin
    // simple VGA signal monitor
    //    if (uut.h_count == 0 && uut.v_count == 0)
    //       $display("Frame start: Ball=(%0d,%0d), Paddle_y=%0d, HSYNC=%b, VSYNC=%b",
    //       uut.ball_x, uut.ball_y, uut.paddle_y, uo_out[0], uo_out[1]);
    // end
   
endmodule

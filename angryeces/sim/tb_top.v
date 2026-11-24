// ============================================================================
// tb_top.v - the whole board design at real speed
//   1. KEY1 starts the game                    -> state AIM
//   2. the slingshot sends '9' over GPIO_1[0]   -> power 9 on HEX0, LEDR3 on
//   3. one video frame is captured off the VGA pins -> frame_top.txt
//   4. KEY1 launches                            -> state FLY, bird moves right
// Slow: ~5 video frames = ~85 ms of sim time.
// ============================================================================
`timescale 1ns / 1ps
module tb_top;
    reg CLOCK_50 = 0;  always #10 CLOCK_50 = ~CLOCK_50;
    reg [3:0] KEY = 4'b1111;
    reg [9:0] SW  = 10'b00_1000_0000;            // angle 45 deg, level 1
    wire [9:0] LEDR;  wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire [7:0] VGA_R, VGA_G, VGA_B;
    wire VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;
    wire [35:0] GPIO_1;
    reg  rx_line = 1'b1;                          // slingshot UART line, idle high
    assign GPIO_1[0] = rx_line;

    angry_eces_top dut (.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .LEDR(LEDR),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .GPIO_1(GPIO_1),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK));

    localparam integer BIT_PERIOD = (50000000 / 9600) * 20;
    task uart_send(input [7:0] data);
        integer b;
        begin
            rx_line <= 1'b0;  #(BIT_PERIOD);
            for (b = 0; b < 8; b = b + 1) begin rx_line <= data[b]; #(BIT_PERIOD); end
            rx_line <= 1'b1;  #(BIT_PERIOD);  #(BIT_PERIOD);
        end
    endtask
    task press_key1; begin KEY[1] = 0; #2_000_000; KEY[1] = 1; #7_000_000; end endtask   // 2 ms press

    // frame capture off the VGA pins
    integer fd, npix = 0;
    reg capture = 0, prev_vs = 1, armed = 0;
    always @(posedge VGA_CLK) begin
        if (capture && VGA_BLANK_N) begin
            $fwrite(fd, "%h%h%h\n", VGA_R[7:4], VGA_G[7:4], VGA_B[7:4]);
            npix = npix + 1;
        end
        if (prev_vs && !VGA_VS) begin                // start of a new frame
            if (capture) begin capture = 0; $fclose(fd); end
            else if (armed) begin capture = 1; armed = 0; fd = $fopen("frame_top.txt", "w"); end
        end
        prev_vs = VGA_VS;
    end

    integer errors = 0, x0;
    initial begin
        KEY[0] = 0; #1000; KEY[0] = 1; #1000;
        if (dut.state !== 3'd0) begin $display("FAIL: not on the title screen"); errors = errors + 1; end

        press_key1;                                               // start
        $display("after KEY1: state=%0d (expect 2 = AIM)", dut.state);
        if (dut.state !== 3'd2) errors = errors + 1;

        uart_send("9");                                           // slingshot pulled to 9
        #100_000;
        $display("slingshot sent '9': power=%0d, shown on HEX0=%0d, LEDR3=%b",
                 dut.power, dut.shown_power, LEDR[3]);
        if (dut.power !== 4'd9 || dut.shown_power !== 4'd9 || LEDR[3] !== 1'b1) errors = errors + 1;

        armed = 1;  wait (capture == 1);  wait (capture == 0);    // grab one full frame
        $display("captured %0d visible pixels into frame_top.txt (expect 307200)", npix);
        if (npix != 307200) errors = errors + 1;

        x0 = dut.bird_x;
        press_key1;                                               // launch
        $display("after launch: state=%0d (expect 3 = FLY)", dut.state);
        if (dut.state !== 3'd3) errors = errors + 1;
        #50_000_000;                                              // 3 frames
        $display("bird x: %0d -> %0d after 3 frames", x0, dut.bird_x);
        if (!(dut.bird_x > x0)) errors = errors + 1;

        if (errors == 0) $display("TOP PASS"); else $display("TOP: %0d FAILURES", errors);
        $stop;
    end
endmodule

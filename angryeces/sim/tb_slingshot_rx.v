// tb_slingshot_rx.v - sends slider digits over UART like the slingshot does
// (uart_send task taken from the slingshot project's testbench.v)
`timescale 1ns / 1ps
module tb_slingshot_rx;
    parameter CLOCK_PERIOD = 20;
    localparam integer BIT_PERIOD = (50000000 / 9600) * CLOCK_PERIOD;   // 104160 ns

    reg CLOCK_50 = 1'b0;
    always #(CLOCK_PERIOD / 2) CLOCK_50 = ~CLOCK_50;

    reg  rx_line = 1'b1;                 // UART idle = high
    wire [3:0] hex_value;
    wire       seen;
    slingshot_rx dut (.CLOCK_50(CLOCK_50), .rx_pin(rx_line), .hex_value(hex_value), .seen(seen));

    // Send one 8N1 UART frame: start bit (0), 8 data bits LSB first, stop bit (1)
    task uart_send;
        input [7:0] data;
        integer b;
        begin
            rx_line <= 1'b0;                 // start bit
            #(BIT_PERIOD);
            for (b = 0; b < 8; b = b + 1) begin
                rx_line <= data[b];          // data bits, LSB first
                #(BIT_PERIOD);
            end
            rx_line <= 1'b1;                 // stop bit
            #(BIT_PERIOD);
            #(BIT_PERIOD);                   // extra idle time between frames
        end
    endtask

    integer errors = 0;
    task send_and_check(input [7:0] ch, input [3:0] expect_val);
        begin
            uart_send(ch);
            if (hex_value !== expect_val || seen !== 1'b1) begin
                $display("FAIL: sent '%c' -> hex_value=%0d (expected %0d)", ch, hex_value, expect_val);
                errors = errors + 1;
            end else
                $display("sent '%c' -> hex_value=%0d", ch, hex_value);
        end
    endtask

    initial begin
        #(BIT_PERIOD);
        if (seen !== 1'b0) begin $display("FAIL: seen set before any byte"); errors = errors + 1; end
        send_and_check("7", 4'd7);
        send_and_check("3", 4'd3);
        send_and_check("A", 4'd10);
        send_and_check("f", 4'd15);
        send_and_check(8'h0A, 4'd15);    // newline is ignored, value stays
        send_and_check("0", 4'd0);
        if (errors == 0) $display("SLINGSHOT UART PASS"); else $display("SLINGSHOT UART: %0d FAILURES", errors);
        $stop;
    end
endmodule

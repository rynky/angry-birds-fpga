module slingshot (
    input wire CLOCK_50,
    output wire [6:0] HEX0,
    output wire [9:0] LEDR,
    inout wire [35:0] GPIO_1
);

    // UART Configuration
    parameter CLK_FREQ  = 50000000;
    parameter BAUD_RATE = 9600;
    parameter CYCLE  = CLK_FREQ / BAUD_RATE;

    // Input Bits
    wire rx_pin = GPIO_1[0];

    // UART Signals
    reg [12:0] clk_count = 0;
    reg [3:0] bit_count = 0;
    reg [7:0] rx_shift_reg = 0;
    reg [7:0] rx_data = 8'h00;
    reg rx_valid = 0;

    // The microcontroller may update during a clock edge
    // Use a second clock cycle to view the proper rx input
    // rx_sync defaults to 11 as UART is idle (high)
    reg [1:0] rx_sync = 2'b11;
    always @(posedge CLOCK_50) begin
        rx_sync <= {rx_sync[0], rx_pin};
    end
    wire rx_final = rx_sync[1];

    // UART Receiver FSM
    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] state = IDLE;

    // 0 (start) -> 8 bits (data) -> 1 (stop)
    always @(posedge CLOCK_50) begin
        rx_valid <= 1'b0; // Default pulse low

        case (state)
            IDLE: begin
                if (rx_final == 1'b0) begin 
                    state <= START;

                    // Move to the middle of the cycle
                    // This should avoid updates on edges
                    clk_count <= CYCLE / 2;
                end
            end

            START: begin
                if (clk_count == 0) begin
                    
                    // Check if it's still a start bit (0)
                    if (rx_final == 1'b0) begin
                        clk_count <= CYCLE;
                        bit_count <= 0;
                        state <= DATA;
                    end 
                    
                    else begin
                        state <= IDLE;
                    end
                
                end else begin
                    clk_count <= clk_count - 1;
                end
            end

            DATA: begin
                
                // Shift register for 8 bits
                // Wait until end of cycle before input
                if (clk_count == 0) begin
                    clk_count <= CYCLE;
                    rx_shift_reg <= {rx_final, rx_shift_reg[7:1]};
                    
                    if (bit_count == 7) begin
                        state <= STOP;
                    end 
                    
                    else begin
                        bit_count <= bit_count + 1;
                    end
                end 
                
                // Count down the clock
                else begin
                    clk_count <= clk_count - 1;
                end
            end

            STOP: begin
                if (clk_count == 0) begin
                    
                    // Stop bit (1)
                    if (rx_final == 1'b1) begin
                        rx_data  <= rx_shift_reg;
                        rx_valid <= 1'b1;
                    end
                    state <= IDLE;

                end 
                
                // Count down the clock
                else begin
                    clk_count <= clk_count - 1;
                end
            end
        endcase
    end

    // Display input digit on the display
    wire [3:0] hex_value;
    ascii_to_hex ascii_decoder (CLOCK_50, rx_valid, rx_data, hex_value);
    char_to_7seg hex_decoder (hex_value, HEX0);

endmodule

// ASCII code to Hexadecimal
module ascii_to_hex(clk, is_valid, ascii, Q);
    input clk;
    input is_valid;
    input [7:0] ascii;
    output reg [3:0] Q = 4'h0;

    always @(posedge clk) begin
        if (is_valid) begin
            // '0'-'9' -> 0-9
            if (ascii >= 8'h30 && ascii <= 8'h39)
                Q <= ascii - 8'h30; 
            
            // 'A'-'F' -> 10-15
            else if (ascii >= 8'h41 && ascii <= 8'h46)
                Q <= ascii - 8'h37; 
            
            // 'a'-'f' -> 10-15
            else if (ascii >= 8'h61 && ascii <= 8'h66)
                Q <= ascii - 8'h57;
        end
    end
endmodule

// 7 Segment Decoder
module char_to_7seg(Q, HEX);
    input [3:0] Q;
    output [6:0] HEX;

    assign HEX[0] = (~Q[3]&~Q[2]&~Q[1]&Q[0]) | (~Q[3]&Q[2]&~Q[1]&~Q[0]) | (Q[3]&~Q[2]&Q[1]&Q[0]) | (Q[3]&Q[2]&~Q[1]&Q[0]);
    assign HEX[1] = (~Q[3]&Q[2]&~Q[1]&Q[0]) | (Q[2]&Q[1]&~Q[0]) | (Q[3]&Q[1]&Q[0]) | (Q[3]&Q[2]&~Q[0]);
    assign HEX[2] = (~Q[3]&~Q[2]&Q[1]&~Q[0]) | (Q[3]&Q[2]&~Q[0]) | (Q[3]&Q[2]&Q[1]);
    assign HEX[3] = (~Q[3]&~Q[2]&~Q[1]&Q[0]) | (~Q[3]&Q[2]&~Q[1]&~Q[0]) | (Q[2]&Q[1]&Q[0]) | (Q[3]&~Q[2]&Q[1]&~Q[0]);
    assign HEX[4] = (~Q[3]&Q[0]) | (~Q[3]&Q[2]&~Q[1]) | (~Q[2]&~Q[1]&Q[0]);
    assign HEX[5] = (~Q[3]&~Q[2]&Q[0]) | (~Q[3]&~Q[2]&Q[1]) | (~Q[3]&Q[1]&Q[0]) | (Q[3]&Q[2]&~Q[1]&Q[0]);
    assign HEX[6] = (~Q[3]&~Q[2]&~Q[1]) | (~Q[3]&Q[2]&Q[1]&Q[0]) | (Q[3]&Q[2]&~Q[1]&~Q[0]);
endmodule
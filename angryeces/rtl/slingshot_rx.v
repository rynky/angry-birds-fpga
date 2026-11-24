module slingshot_rx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 9600
) (
    input wire CLOCK_50,
    input wire rx_pin, // GPIO_1[0] input
    output wire [3:0] hex_value, // last slider digit
    output reg seen = 1'b0 // byte received flag
);
    parameter CYCLE = CLK_FREQ / BAUD_RATE;

    // UART signals
    reg [12:0] clk_count = 0;
    reg [3:0] bit_count = 0;
    reg [7:0] rx_shift_reg = 0;
    reg [7:0] rx_data = 8'h00;
    reg rx_valid = 0;

    // synchronize rx input
    reg [1:0] rx_sync = 2'b11;
    always @(posedge CLOCK_50) begin
        rx_sync <= {rx_sync[0], rx_pin};
    end
    wire rx_final = rx_sync[1];

    // UART receiver FSM
    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] state = IDLE;

    // UART state machine
    always @(posedge CLOCK_50) begin
        rx_valid <= 1'b0; // default pulse low
        case (state)
            IDLE: begin
                if (rx_final == 1'b0) begin
                    state <= START;
                    // sample bit middle
                    clk_count <= CYCLE / 2;
                end
            end
            START: begin
                if (clk_count == 0) begin
                    // verify start bit
                    if (rx_final == 1'b0) begin
                        clk_count <= CYCLE;
                        bit_count <= 0;
                        state <= DATA;
                    end else begin
                        state <= IDLE;
                    end
                end else begin
                    clk_count <= clk_count - 1;
                end
            end
            DATA: begin
                // shift data bits
                if (clk_count == 0) begin
                    clk_count <= CYCLE;
                    rx_shift_reg <= {rx_final, rx_shift_reg[7:1]};
                    if (bit_count == 7) begin
                        state <= STOP;
                    end else begin
                        bit_count <= bit_count + 1;
                    end
                end else begin
                    // wait one cycle
                    clk_count <= clk_count - 1;
                end
            end
            STOP: begin
                if (clk_count == 0) begin
                    // verify stop bit
                    if (rx_final == 1'b1) begin
                        rx_data <= rx_shift_reg;
                        rx_valid <= 1'b1;
                    end
                    state <= IDLE;
                end else begin
                    // wait one cycle
                    clk_count <= clk_count - 1;
                end
            end
        endcase
    end

    // latch connected flag
    always @(posedge CLOCK_50)
        if (rx_valid) seen <= 1'b1;

    // decode ASCII digit
    ascii_to_hex ascii_decoder (CLOCK_50, rx_valid, rx_data, hex_value);
endmodule

// ASCII to hex
module ascii_to_hex(clk, is_valid, ascii, Q);
    input clk;
    input is_valid;
    input [7:0] ascii;
    output reg [3:0] Q = 4'h0;

    always @(posedge clk) begin
        if (is_valid) begin
            // digits 0-9
            if (ascii >= 8'h30 && ascii <= 8'h39)
                Q <= ascii - 8'h30;
            // uppercase A-F
            else if (ascii >= 8'h41 && ascii <= 8'h46)
                Q <= ascii - 8'h37;
            // lowercase a-f
            else if (ascii >= 8'h61 && ascii <= 8'h66)
                Q <= ascii - 8'h57;
        end
    end
endmodule
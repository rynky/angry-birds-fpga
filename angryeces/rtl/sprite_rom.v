module sprite_rom #(
    parameter WIDTH = 12,
    parameter ADDR_BITS=12, 
    parameter INIT_FILE="rom/pig.hex"
)(
    input wire clk,
    input wire [ADDR_BITS-1:0] addr,
    output reg [WIDTH-1:0] q
);
    reg [WIDTH-1:0] mem [0:(1<<ADDR_BITS)-1]; 
    initial $readmemh(INIT_FILE,mem); 
    always @(posedge clk) begin
        q <= mem[addr];
    end
endmodule

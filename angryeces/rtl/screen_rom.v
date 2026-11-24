module screen_rom (clk,h,v,screen,rgb);
    input wire clk;
    input wire [9:0]h;
    input wire [9:0]v;
    input wire [2:0] screen;
    output reg [11:0] rgb;

    localparam W = 160,H=120,N = 8;

    reg [11:0] mem [0:N*W*H-1];
    initial $readmemh("rom/screens.hex", mem);

    wire [7:0]x = h[9:2];
    wire [6:0] y= v[8:2]; 
    wire [17:0] addr=screen *18'd19200+{y,7'b0}+{y, 5'b0} +x;

    always @(posedge clk)rgb<=mem[addr];
endmodule

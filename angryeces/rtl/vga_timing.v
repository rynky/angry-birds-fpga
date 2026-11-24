module vga_timing (clk, rst,pix_en, h,v,visible,hsync_n,vsync_n,frame_tick);
    input wire clk;
    input wire rst;
    output reg pix_en;
    output reg [9:0]h;
    output reg [9:0] v;
    output wire visible;
    output wire hsync_n;
    output wire vsync_n;
    output wire frame_tick;

    localparam H_VIS = 640,H_FP = 16,H_SYNC=96, H_BP= 48, H_TOT=800;
    localparam V_VIS =480,V_FP=10,V_SYNC=2, V_BP=33, V_TOT=525;

    initial begin
        pix_en = 1'b0;
        h=0;
        v =0;
    end

    always @(posedge clk) begin
        if (rst) begin
            pix_en <= 1'b0;
            h<=0;
            v <=0;
        end else begin
            pix_en<=~pix_en;
            if (pix_en) begin
                if (h==H_TOT -1) begin
                    h <=10'd0;
                    v <= (v==V_TOT - 1)?10'd0 : v +10'd1;
                end else begin
                    h <= h + 10'd1;
                end
            end
        end
    end

    assign visible=(h < H_VIS) && (v < V_VIS);
    assign hsync_n = ~((h >= H_VIS + H_FP) && (h < H_VIS + H_FP + H_SYNC));
    assign vsync_n = ~((v >= V_VIS + V_FP) && (v < V_VIS + V_FP + V_SYNC));
    assign frame_tick = pix_en && (h == H_TOT - 1) && (v == V_VIS - 1);
endmodule
module level_data (level, index, block, pig

);

    input wire [1:0] level;
    input wire [3:0]index;
    output reg [18:0]block;
    output reg [17:0] pig;

    localparam V = 1'b0, H = 1'b1;

    always @* begin
        block = 19'd0;
        case ({level, index})
            // Level 1 one hut
            {2'd0, 4'd0}:block= {1'b1, V, 9'd220, 8'd160};
            {2'd0, 4'd1}:block= {1'b1, V, 9'd252, 8'd160};
            {2'd0, 4'd2}:block= {1'b1, H, 9'd220, 8'd152};
            {2'd0, 4'd3}:block= {1'b1, V, 9'd290, 8'd160};
            //Level two two story hut
            {2'd1, 4'd0}: block = {1'b1, V, 9'd200, 8'd160};
            {2'd1, 4'd1}: block = {1'b1, V, 9'd232, 8'd160};
            {2'd1, 4'd2}: block = {1'b1, H, 9'd200, 8'd152};
            {2'd1, 4'd3}: block = {1'b1, V, 9'd200, 8'd112};
            {2'd1, 4'd4}: block = {1'b1, V, 9'd232, 8'd112};
            {2'd1, 4'd5}: block = {1'b1, H, 9'd200, 8'd104};
            {2'd1, 4'd6}: block = {1'b1, V, 9'd262, 8'd160};
            {2'd1, 4'd7}: block = {1'b1, V, 9'd294, 8'd160};
            {2'd1, 4'd8}: block = {1'b1, H, 9'd262, 8'd152};
            //Level 3 twin towers
            {2'd2, 4'd0}: block = {1'b1, V, 9'd176, 8'd160};
            {2'd2, 4'd1}: block = {1'b1, V, 9'd208, 8'd160};
            {2'd2, 4'd2}: block = {1'b1, H, 9'd176, 8'd152};
            {2'd2, 4'd3}: block = {1'b1, V, 9'd176, 8'd112};
            {2'd2, 4'd4}: block = {1'b1, V, 9'd208, 8'd112};
            {2'd2, 4'd5}: block = {1'b1, H, 9'd176, 8'd104};
            {2'd2, 4'd6}: block = {1'b1, V, 9'd244, 8'd160};
            {2'd2, 4'd7}: block = {1'b1, V, 9'd276, 8'd160};
            {2'd2, 4'd8}: block = {1'b1, H, 9'd244, 8'd152};
            {2'd2, 4'd9}: block = {1'b1, V, 9'd244, 8'd112};
            {2'd2, 4'd10}: block = {1'b1, V, 9'd276, 8'd112};
            {2'd2, 4'd11}: block = {1'b1, H, 9'd244, 8'd104};
            default: block = 19'd0;
        endcase

        pig = 18'd0;
        case ({level, index})
            {2'd0, 4'd0}: pig={1'b1, 9'd230, 8'd180};
            {2'd0, 4'd1}: pig ={1'b1, 9'd230, 8'd132};
            {2'd1, 4'd0}: pig= {1'b1, 9'd210, 8'd180};
            {2'd1, 4'd1}: pig={1'b1, 9'd210, 8'd132};
            {2'd1, 4'd2}: pig ={1'b1, 9'd272, 8'd180};
            {2'd2, 4'd0}: pig ={1'b1, 9'd186, 8'd132};
            {2'd2, 4'd1}: pig ={1'b1, 9'd254, 8'd180};
            {2'd2, 4'd2}: pig ={1'b1, 9'd254, 8'd84};
            default: pig =18'd0;
        endcase
    end
endmodule

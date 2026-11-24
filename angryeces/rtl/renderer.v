module renderer #(
    parameter Num_blocks=12,
    parameter Num_pigs=3,
    parameter Num_dots=10
) (
    input wire clk,
    input wire [9:0] h,
    input wire [9:0] v,
    input wire [Num_blocks*9-1:0] blk_x_f,
    input wire [Num_blocks*8-1:0] blk_y_f,
    input wire [Num_blocks-1:0] blk_horiz,
    input wire [Num_blocks-1:0] blk_alive,
    input wire [Num_pigs*9-1:0] pig_x_f,
    input wire [Num_pigs*8-1:0] pig_y_f,
    input wire [Num_pigs-1:0] pig_alive,
    input wire [Num_blocks-1:0] blk_flash,
    input wire [Num_pigs-1:0] pig_flash,
    input wire signed [9:0] bird_x,
    input wire signed [9:0] bird_y,
    input wire [1:0] bird_type,
    input wire bird_vis,
    input wire [2:0] waiting,
    input wire [Num_dots*9-1:0] dot_x_f,
    input wire [Num_dots*8-1:0] dot_y_f,
    input wire [Num_dots-1:0] dot_on,
    input wire exp_on,
    input wire [8:0] exp_x,
    input wire [7:0] exp_y,
    input wire [5:0] exp_r,
    input wire [5:0] line_en,
    input wire [23:0] line_msg,
    input wire dim,
    output reg [11:0] rgb
);
    localparam [11:0] TRANSPARENT_COLOR = 12'hF0F;
    wire [8:0] game_x = h[9:1];
    wire [7:0] game_y = v[8:1];

    reg block_hit_any, block_flash_any;
    reg [6:0] block_row;
    reg [3:0] block_column;
    reg [4:0] block_index;
    reg [9:0] current_block_x,current_block_y,current_block_width,current_block_height;
    reg [9:0] block_offset_x,block_offset_y;
    always @* begin
        block_hit_any=1'b0;
        block_flash_any=1'b0;
        block_row=7'd0;
        block_column=4'd0;
        for (block_index=5'd0; block_index<Num_blocks; block_index=block_index+5'd1) begin
            current_block_x = {blk_x_f[block_index*9 +: 9],1'b0};
            current_block_y = {1'b0,blk_y_f[block_index*8 +: 8],1'b0};
            if (blk_horiz[block_index]) begin
                current_block_width=10'd80;
                current_block_height=10'd16;
            end else begin
                current_block_width=10'd16;
                current_block_height=10'd80;
            end
            block_offset_x = h-current_block_x;
            block_offset_y = v-current_block_y;
            if (!block_hit_any && blk_alive[block_index] && (h>=current_block_x) && (h<current_block_x+current_block_width) && (v>=current_block_y) && (v<current_block_y+current_block_height)) begin
                block_hit_any=1'b1;
                block_flash_any=blk_flash[block_index];
                if (blk_horiz[block_index]) begin
                    block_row = block_offset_x[6:0];
                    block_column = 4'd15-block_offset_y[3:0];
                end else begin
                    block_row = block_offset_y[6:0];
                    block_column = block_offset_x[3:0];
                end
            end
        end
    end

    wire [11:0] wood_pixel;
    sprite_rom #(.WIDTH(12),.ADDR_BITS(11),.INIT_FILE("rom/wood.hex")) wood_rom_inst (.clk(clk),.addr({block_row,block_column}),.q(wood_pixel));

    reg pig_hit_any, pig_flash_any;
    reg [11:0] pig_rom_address;
    reg [4:0] pig_index;
    reg [9:0] current_pig_x,current_pig_y,pig_offset_x,pig_offset_y;
    always @* begin
        pig_hit_any=1'b0;
        pig_flash_any=1'b0;
        pig_rom_address=12'd0;
        for (pig_index=5'd0; pig_index<Num_pigs; pig_index=pig_index+5'd1) begin
            current_pig_x = {pig_x_f[pig_index*9 +: 9],1'b0};
            current_pig_y = {1'b0,pig_y_f[pig_index*8 +: 8],1'b0};
            pig_offset_x = h-current_pig_x;
            pig_offset_y = v-current_pig_y;
            if (!pig_hit_any && pig_alive[pig_index] && (h>=current_pig_x) && (h<current_pig_x+10'd40) && (v>=current_pig_y) && (v<current_pig_y+10'd40)) begin
                pig_hit_any=1'b1;
                pig_flash_any=pig_flash[pig_index];
                pig_rom_address = {pig_offset_y[5:0],pig_offset_x[5:0]};
            end
        end
    end

    wire [11:0] pig_pixel;
    sprite_rom #(.WIDTH(12),.ADDR_BITS(12),.INIT_FILE("rom/pig.hex")) pig_rom_inst (.clk(clk),.addr(pig_rom_address),.q(pig_pixel));

    wire signed [11:0] horizontal_signed = {2'b00,h};
    wire signed [11:0] vertical_signed = {2'b00,v};
    wire signed [11:0] active_bird_offset_x = horizontal_signed - $signed({bird_x,1'b0});
    wire signed [11:0] active_bird_offset_y = vertical_signed - $signed({bird_y,1'b0});
    wire active_bird_hit = bird_vis && (active_bird_offset_x>=0) && (active_bird_offset_x<40) && (active_bird_offset_y>=0) && (active_bird_offset_y<40);
    wire waiting_bird_one_hit = waiting[1] && (h>=10'd40) && (h<10'd80) && (v>=10'd360) && (v<10'd400);
    wire waiting_bird_two_hit = waiting[2] && (h<10'd40) && (v>=10'd360) && (v<10'd400);
    wire [9:0] waiting_bird_one_offset_x = h-10'd40;
    wire [9:0] waiting_bird_offset_y = v-10'd360;

    reg bird_hit_any;
    reg [13:0] bird_rom_address;
    always @* begin
        bird_hit_any=1'b1;
        if (active_bird_hit) bird_rom_address = {bird_type,active_bird_offset_y[5:0],active_bird_offset_x[5:0]};
        else if (waiting_bird_one_hit) bird_rom_address = {2'd1,waiting_bird_offset_y[5:0],waiting_bird_one_offset_x[5:0]};
        else if (waiting_bird_two_hit) bird_rom_address = {2'd2,waiting_bird_offset_y[5:0],h[5:0]};
        else begin
            bird_rom_address=14'd0;
            bird_hit_any=1'b0;
        end
    end

    wire [11:0] bird_pixel;
    sprite_rom #(.WIDTH(12),.ADDR_BITS(14),.INIT_FILE("rom/birds.hex")) bird_rom_inst (.clk(clk),.addr(bird_rom_address),.q(bird_pixel));

    reg dot_hit_any;
    reg [4:0] dot_index;
    always @* begin
        dot_hit_any=1'b0;
        for (dot_index=5'd0; dot_index<Num_dots; dot_index=dot_index+5'd1) begin
            if (dot_on[dot_index] && (game_x>=dot_x_f[dot_index*9 +: 9]) && (game_x<dot_x_f[dot_index*9 +: 9]+9'd2) && (game_y>=dot_y_f[dot_index*8 +: 8]) && (game_y<dot_y_f[dot_index*8 +: 8]+8'd2))
                dot_hit_any=1'b1;
        end
    end

    wire signed [10:0] explosion_offset_x = $signed({2'b00,game_x}) - $signed({2'b00,exp_x});
    wire signed [10:0] explosion_offset_y = $signed({3'b000,game_y}) - $signed({3'b000,exp_y});
    wire [21:0] explosion_distance_squared = explosion_offset_x*explosion_offset_x + explosion_offset_y*explosion_offset_y;
    wire [11:0] explosion_radius_squared = exp_r*exp_r;
    wire explosion_hit = exp_on && (explosion_distance_squared<explosion_radius_squared);
    wire explosion_inner = (explosion_distance_squared < (explosion_radius_squared>>2));

    reg text_in_bounds;
    reg [3:0] text_message;
    reg [2:0] text_row;
    reg [6:0] text_column;
    always @* begin
        text_in_bounds=1'b0; text_message=4'd0; text_row=3'd0; text_column=7'd0;
        if (line_en[0] && game_y>=8'd4 && game_y<8'd12 && game_x>=9'd4 && game_x<9'd132) begin
            text_in_bounds=1'b1; text_message=line_msg[3:0]; text_row=game_y-8'd4; text_column=game_x-9'd4;
        end else if (line_en[1] && game_y>=8'd60 && game_y<8'd76 && game_x>=9'd32 && game_x<9'd288) begin
            text_in_bounds=1'b1; text_message=line_msg[7:4]; text_row=(game_y-8'd60)>>1; text_column=(game_x-9'd32)>>1;
        end else if (line_en[2] && game_y>=8'd84 && game_y<8'd100 && game_x>=9'd32 && game_x<9'd288) begin
            text_in_bounds=1'b1; text_message=line_msg[11:8]; text_row=(game_y-8'd84)>>1; text_column=(game_x-9'd32)>>1;
        end else if (line_en[3] && game_y>=8'd112 && game_y<8'd120 && game_x>=9'd96 && game_x<9'd224) begin
            text_in_bounds=1'b1; text_message=line_msg[15:12]; text_row=game_y-8'd112; text_column=game_x-9'd96;
        end else if (line_en[4] && game_y>=8'd122 && game_y<8'd130 && game_x>=9'd96 && game_x<9'd224) begin
            text_in_bounds=1'b1; text_message=line_msg[19:16]; text_row=game_y-8'd122; text_column=game_x-9'd96;
        end else if (line_en[5] && game_y>=8'd132 && game_y<8'd140 && game_x>=9'd96 && game_x<9'd224) begin
            text_in_bounds=1'b1; text_message=line_msg[23:20]; text_row=game_y-8'd132; text_column=game_x-9'd96;
        end
    end

    wire [127:0] text_rom_data;
    sprite_rom #(.WIDTH(128),.ADDR_BITS(7),.INIT_FILE("rom/text.hex")) text_rom_inst (.clk(clk),.addr({text_message,text_row}),.q(text_rom_data));
    wire text_pixel = text_in_bounds && text_rom_data[7'd127-text_column];

    localparam [8:0] CLOUD_ONE_X=9'd58, CLOUD_TWO_X=9'd183;
    localparam [7:0] CLOUD_ONE_Y=8'd17, CLOUD_TWO_Y=8'd32;

    wire [8:0] cloud_one_offset_x = game_x-CLOUD_ONE_X;
    wire [7:0] cloud_one_offset_y = game_y-CLOUD_ONE_Y;
    wire [8:0] cloud_two_offset_x = game_x-CLOUD_TWO_X;
    wire [7:0] cloud_two_offset_y = game_y-CLOUD_TWO_Y;
    wire cloud_one_hit = (game_x>=CLOUD_ONE_X) && (cloud_one_offset_x<9'd64) && (game_y>=CLOUD_ONE_Y) && (cloud_one_offset_y<8'd64);
    wire cloud_two_hit = (game_x>=CLOUD_TWO_X) && (cloud_two_offset_x<9'd64) && (game_y>=CLOUD_TWO_Y) && (cloud_two_offset_y<8'd64);

    reg cloud_hit_any;
    reg [12:0] cloud_rom_address;
    always @* begin
        cloud_hit_any=1'b1;
        if (cloud_one_hit) cloud_rom_address = {1'b0,cloud_one_offset_y[5:0],cloud_one_offset_x[5:0]};
        else if (cloud_two_hit) cloud_rom_address = {1'b1,cloud_two_offset_y[5:0],cloud_two_offset_x[5:0]};
        else begin
            cloud_rom_address=13'd0;
            cloud_hit_any=1'b0;
        end
    end

    wire [11:0] cloud_pixel;
    sprite_rom #(.WIDTH(12),.ADDR_BITS(13),.INIT_FILE("rom/clouds.hex")) cloud_rom_inst (.clk(clk),.addr(cloud_rom_address),.q(cloud_pixel));

    wire [5:0] hill_phase = game_x[5:0]+6'd32;
    reg [4:0] hill_wave;
    always @* begin
        if (hill_phase[5]) hill_wave=~hill_phase[4:0];
        else hill_wave=hill_phase[4:0];
    end
    wire hill_hit = (game_y >= 8'd176+(8'd15-{4'd0,hill_wave[4:1]}));

    wire slingshot_post = (game_x>=9'd47 && game_x<9'd53 && game_y>=8'd178 && game_y<8'd200);
    wire slingshot_arms = ((game_x>=9'd41 && game_x<9'd46) || (game_x>=9'd54 && game_x<9'd59)) && game_y>=8'd160 && game_y<8'd182;
    wire slingshot_bar = (game_x>=9'd41 && game_x<9'd59 && game_y>=8'd177 && game_y<8'd183);
    wire slingshot_hit = slingshot_post | slingshot_arms | slingshot_bar;
    wire slingshot_edge = slingshot_hit && (game_x==9'd41 || game_x==9'd58 || game_x==9'd47 || game_x==9'd52);

    reg [11:0] background_color;
    always @* begin
        if (game_y>=8'd200) begin
            if (game_y<8'd203) background_color=12'h4C2;
            else if (game_y<8'd205) background_color=12'h3A1;
            else if (game_x[3]^game_y[3]) background_color=12'h853;
            else background_color=12'h964;
        end else if (hill_hit) begin
            if (game_y<8'd186) background_color=12'h7C6;
            else background_color=12'h6B5;
        end else if (cloud_hit_any && cloud_pixel!=TRANSPARENT_COLOR) begin
            background_color=cloud_pixel;
        end else begin
            background_color = {4'd4+{1'b0,game_y[7:5]}, 4'd9+{2'b0,game_y[7:6]}, 4'hF};
        end
        if (slingshot_hit) begin
            if (slingshot_edge) background_color=12'h420;
            else background_color=12'h742;
        end
    end

    reg [11:0] final_color;
    always @* begin
        final_color=background_color;
        if (block_hit_any && wood_pixel!=TRANSPARENT_COLOR) begin
            if (block_flash_any) final_color=12'hFFF;
            else final_color=wood_pixel;
        end
        if (pig_hit_any && pig_pixel!=TRANSPARENT_COLOR) begin
            if (pig_flash_any) final_color=12'hFFF;
            else final_color=pig_pixel;
        end
        if (dot_hit_any) final_color=12'hFFF;
        if (bird_hit_any && bird_pixel!=TRANSPARENT_COLOR) final_color=bird_pixel;
        if (explosion_hit) begin
            if (explosion_inner) final_color=12'hFF6;
            else final_color=12'hF80;
        end
        if (dim && game_y>=8'd52 && game_y<8'd144)
            final_color = {1'b0,final_color[11:9],1'b0,final_color[7:5],1'b0,final_color[3:1]};
        if (text_pixel) begin
            if (text_message>=4'd6 && text_message<=4'd8) final_color=12'h000;
            else final_color=12'hFF0;
        end
        rgb=final_color;
    end
endmodule
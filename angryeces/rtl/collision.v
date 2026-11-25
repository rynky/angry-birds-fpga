module collision #(parameter Num_blocks=12, parameter Num_pigs=3, parameter MAX_HEALTH=3, parameter FLASH_FRAMES=15)(
    input wire clk,
    input wire reset,
    input wire frame_tick,
    input wire active, // bird is flying
    input wire signed [9:0] bird_x,
    input wire signed [9:0] bird_y,

    input wire [Num_blocks*9-1:0] blk_x_f,
    input wire [Num_blocks*8-1:0] blk_y_f,
    input wire [Num_blocks-1:0] blk_horiz,
    input wire [Num_blocks-1:0] blk_alive,
    input wire [Num_pigs*9-1:0] pig_x_f,
    input wire [Num_pigs*8-1:0] pig_y_f,
    input wire [Num_pigs-1:0] pig_alive,

    output wire pause,
    output wire [Num_blocks-1:0] blk_flash,
    output wire [Num_pigs-1:0] pig_flash,
    output wire [Num_blocks-1:0] blk_kill,
    output wire [Num_pigs-1:0] pig_kill,
    output wire spent, // last health used
    output reg [1:0] health
);
    parameter OBSTACLE_IDLE = 2'd0, OBSTACLE_FLY = 2'd1, OBSTACLE_FLASH = 2'd2, OBSTACLE_REMOVE = 2'd3;

    reg [1:0] col_state;
    reg [4:0] flash_timer;
    reg [Num_blocks-1:0] target_block;
    reg [Num_pigs-1:0] target_pig;

    parameter signed [11:0] BIRD_LEFT = 12'sd3, BIRD_RIGHT = 12'sd17, BIRD_TOP = 12'sd6, BIRD_BOTTOM = 12'sd20; // hitbox size factor
    parameter [11:0] PIG_LEFT = 12'd2, PIG_RIGHT = 12'd18, PIG_TOP = 12'd5, PIG_BOTTOM = 12'd20; // hitbox size factor

    wire signed [11:0] bird_left = bird_x + BIRD_LEFT, bird_right = bird_x + BIRD_RIGHT;
    wire signed [11:0] bird_top = bird_y + BIRD_TOP, bird_bottom = bird_y + BIRD_BOTTOM;

    reg any_hit;
    reg [Num_blocks-1:0] block_pick;
    reg [Num_pigs-1:0] pig_pick;
    reg [4:0] loop_index;
    reg [8:0] block_width, block_height;
    reg signed [11:0] box_left, box_right, box_top, box_bottom;
    always @(*) begin
        any_hit = 1'b0;
        block_pick = {Num_blocks{1'b0}};
        pig_pick = {Num_pigs{1'b0}};
        block_width = 9'd0;
        block_height = 9'd0;
        box_left = 12'sd0;
        box_right = 12'sd0;
        box_top = 12'sd0;
        box_bottom = 12'sd0;
        for (loop_index = 5'd0; loop_index < Num_pigs; loop_index = loop_index + 5'd1) begin // pigs take priority
            box_left = {3'b000, pig_x_f[loop_index*9 +: 9]} + PIG_LEFT;
            box_right = {3'b000, pig_x_f[loop_index*9 +: 9]} + PIG_RIGHT;
            box_top = {4'b0000, pig_y_f[loop_index*8 +: 8]} + PIG_TOP;
            box_bottom = {4'b0000, pig_y_f[loop_index*8 +: 8]} + PIG_BOTTOM;
            if (!any_hit && pig_alive[loop_index] && (bird_left < box_right) && (box_left < bird_right) &&
                (bird_top < box_bottom) && (box_top < bird_bottom)) begin
                any_hit = 1'b1;
                pig_pick[loop_index] = 1'b1;
            end
        end
        for (loop_index = 5'd0; loop_index < Num_blocks; loop_index = loop_index + 5'd1) begin
            if (blk_horiz[loop_index]) begin
                block_width = 9'd40;
                block_height = 9'd8;
            end else begin
                block_width = 9'd8;
                block_height = 9'd40;
            end
            box_left = {3'b000, blk_x_f[loop_index*9 +: 9]};
            box_right = {3'b000, blk_x_f[loop_index*9 +: 9]} + {3'b000, block_width};
            box_top = {4'b0000, blk_y_f[loop_index*8 +: 8]};
            box_bottom = {4'b0000, blk_y_f[loop_index*8 +: 8]} + {3'b000, block_height};
            if (!any_hit && blk_alive[loop_index] && (bird_left < box_right) && (box_left < bird_right) &&
                (bird_top < box_bottom) && (box_top < bird_bottom)) begin
                any_hit = 1'b1;
                block_pick[loop_index] = 1'b1;
            end
        end
    end

    assign pause = (col_state == OBSTACLE_FLASH) || (col_state == OBSTACLE_REMOVE);
    assign blk_flash = target_block & {Num_blocks{pause}};
    assign pig_flash = target_pig & {Num_pigs{pause}};
    assign blk_kill = target_block & {Num_blocks{(col_state == OBSTACLE_REMOVE)}};
    assign pig_kill = target_pig & {Num_pigs{(col_state == OBSTACLE_REMOVE)}};
    assign spent = (col_state == OBSTACLE_REMOVE) && (health == 2'd1);

    always @(posedge clk) begin
        if (reset) begin
            col_state <= OBSTACLE_IDLE;
            health <= MAX_HEALTH;
            flash_timer <= 5'd0;
            target_block <= {Num_blocks{1'b0}};
            target_pig <= {Num_pigs{1'b0}};
        end else begin
            case (col_state)
                OBSTACLE_IDLE: begin
                    health <= MAX_HEALTH;
                    target_block <= {Num_blocks{1'b0}};
                    target_pig <= {Num_pigs{1'b0}};
                    if (active) col_state <= OBSTACLE_FLY;
                end
                OBSTACLE_FLY: begin
                    if (!active) col_state <= OBSTACLE_IDLE;
                    else if (frame_tick && any_hit) begin
                        target_block <= block_pick;
                        target_pig <= pig_pick;
                        flash_timer <= 5'd0;
                        col_state <= OBSTACLE_FLASH;
                    end
                end
                OBSTACLE_FLASH: if (frame_tick) begin
                    flash_timer <= flash_timer + 5'd1;
                    if (flash_timer == FLASH_FRAMES - 1) col_state <= OBSTACLE_REMOVE;
                end
                OBSTACLE_REMOVE: if (frame_tick) begin
                    health <= health - 2'd1;
                    target_block <= {Num_blocks{1'b0}};
                    target_pig <= {Num_pigs{1'b0}};
                    if (health == 2'd1) col_state <= OBSTACLE_IDLE; // out of health
                    else col_state <= OBSTACLE_FLY;
                end
                default: col_state <= OBSTACLE_IDLE;
            endcase
        end
    end
endmodule

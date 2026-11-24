// Bird vs block/pig collision.
// When the flying bird touches a live block or pig, the bird is paused, the obstacle
// flashes white for FLASH_FRAMES frames, then the obstacle is removed and the flight
// continues. Each break costs one health; on the last break the bird is spent.
module collision #(parameter Num_blocks=12, parameter Num_pigs=3, parameter MAX_HEALTH=3, parameter FLASH_FRAMES=15)(
    input wire clk,
    input wire reset,
    input wire frame_tick,
    input wire active,                          // bird is flying and visible
    input wire signed [9:0] bird_x,
    input wire signed [9:0] bird_y,

    input wire [Num_blocks*9-1:0] blk_x_f,
    input wire [Num_blocks*8-1:0] blk_y_f,
    input wire [Num_blocks-1:0] blk_horiz,
    input wire [Num_blocks-1:0] blk_alive,
    input wire [Num_pigs*9-1:0] pig_x_f,
    input wire [Num_pigs*8-1:0] pig_y_f,
    input wire [Num_pigs-1:0] pig_alive,

    output wire pause,                          // freeze bird motion
    output wire [Num_blocks-1:0] blk_flash,     // draw these blocks white
    output wire [Num_pigs-1:0] pig_flash,       // draw these pigs white
    output wire [Num_blocks-1:0] blk_kill,      // remove these blocks (held for one frame)
    output wire [Num_pigs-1:0] pig_kill,        // remove these pigs (held for one frame)
    output wire spent,                          // this break used the last health
    output reg [1:0] health
);
    localparam S_IDLE = 2'd0, S_FLY = 2'd1, S_FLASH = 2'd2, S_REMOVE = 2'd3;

    reg [1:0] col_state;
    reg [4:0] flash_timer;
    reg [Num_blocks-1:0] target_block;
    reg [Num_pigs-1:0] target_pig;

    // Sprites are drawn as 20x20 game pixels, but the art is round with a tuft/ears on top.
    // Hitboxes are inset to the solid body so empty corners never register a hit.
    // bird: 14x14 body at (+3,+6) inside its 20x20 sprite
    localparam signed [11:0] BIRD_LEFT = 12'sd3, BIRD_RIGHT = 12'sd17, BIRD_TOP = 12'sd6, BIRD_BOTTOM = 12'sd20;
    // pig: 16x15 body at (+2,+5) inside its 20x20 sprite
    localparam [11:0] PIG_LEFT = 12'd2, PIG_RIGHT = 12'd18, PIG_TOP = 12'd5, PIG_BOTTOM = 12'd20;

    wire signed [11:0] bird_left = bird_x + BIRD_LEFT, bird_right = bird_x + BIRD_RIGHT;
    wire signed [11:0] bird_top = bird_y + BIRD_TOP, bird_bottom = bird_y + BIRD_BOTTOM;

    // pick exactly one target: the first overlapping live pig, otherwise the first overlapping live block
    reg any_hit;
    reg [Num_blocks-1:0] block_pick;
    reg [Num_pigs-1:0] pig_pick;
    reg [4:0] loop_index;
    reg [8:0] block_width, block_height;
    reg signed [11:0] box_left, box_right, box_top, box_bottom;
    always @* begin
        any_hit = 1'b0;
        block_pick = {Num_blocks{1'b0}};
        pig_pick = {Num_pigs{1'b0}};
        block_width = 9'd0;
        block_height = 9'd0;
        box_left = 12'sd0;
        box_right = 12'sd0;
        box_top = 12'sd0;
        box_bottom = 12'sd0;
        // pigs: inset body box
        for (loop_index = 5'd0; loop_index < Num_pigs; loop_index = loop_index + 5'd1) begin
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
        // blocks: 8x40 vertical, 40x8 horizontal
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

    assign pause = (col_state == S_FLASH) || (col_state == S_REMOVE);
    assign blk_flash = target_block & {Num_blocks{pause}};
    assign pig_flash = target_pig & {Num_pigs{pause}};
    assign blk_kill = target_block & {Num_blocks{(col_state == S_REMOVE)}};
    assign pig_kill = target_pig & {Num_pigs{(col_state == S_REMOVE)}};
    assign spent = (col_state == S_REMOVE) && (health == 2'd1);

    always @(posedge clk) begin
        if (reset) begin
            col_state <= S_IDLE;
            health <= MAX_HEALTH;
            flash_timer <= 5'd0;
            target_block <= {Num_blocks{1'b0}};
            target_pig <= {Num_pigs{1'b0}};
        end else begin
            case (col_state)
                S_IDLE: begin
                    health <= MAX_HEALTH;
                    target_block <= {Num_blocks{1'b0}};
                    target_pig <= {Num_pigs{1'b0}};
                    if (active) col_state <= S_FLY;
                end
                S_FLY: begin
                    if (!active) col_state <= S_IDLE;
                    else if (frame_tick && any_hit) begin
                        target_block <= block_pick;
                        target_pig <= pig_pick;
                        flash_timer <= 5'd0;
                        col_state <= S_FLASH;
                    end
                end
                S_FLASH: if (frame_tick) begin
                    flash_timer <= flash_timer + 5'd1;
                    if (flash_timer == FLASH_FRAMES - 1) col_state <= S_REMOVE;
                end
                S_REMOVE: if (frame_tick) begin
                    health <= health - 2'd1;
                    target_block <= {Num_blocks{1'b0}};
                    target_pig <= {Num_pigs{1'b0}};
                    if (health == 2'd1) col_state <= S_IDLE;
                    else col_state <= S_FLY;
                end
                default: col_state <= S_IDLE;
            endcase
        end
    end
endmodule

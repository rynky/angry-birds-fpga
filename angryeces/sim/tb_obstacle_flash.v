`timescale 1ns / 1ps
// Obstacle flash and removal: the bird flies into a pig on a two-block tower and breaks all three. Ends with OBSTACLE PASS / FAIL.
module tb_obstacle_flash;
    localparam NB = 12, NP = 3, ND = 10, FULL_POWER = 15;
    localparam [2:0] S_TITLE = 3'd0, S_LOAD = 3'd1, S_AIM = 3'd2, S_FLY = 3'd3,
                     S_SETTLE = 3'd4, S_CLEAR = 3'd5, S_OVER = 3'd6, S_WIN = 3'd7;
    localparam [1:0] C_IDLE = 2'd0, C_FLY = 2'd1, C_FLASH = 2'd2, C_REMOVE = 2'd3;
    localparam integer GRAVITY = 4, FLASH_FRAMES = 15, POINTS_PIG = 50, POINTS_BLOCK = 5;
    localparam integer TOWER_X = 135; // tower sits in the falling part of a power 0 shot

    reg clk = 0;
    always #10 clk = ~clk;

    reg rst = 1, frame_tick = 0, key_press = 0;
    reg key_up = 0, key_down = 0;
    reg [9:0] sw = 10'd0;
    reg [3:0] power = 4'd0;

    wire [2:0] state;
    wire [1:0] level, bird;
    wire [9:0] pts_add;
    wire new_game, game_end;
    wire bird_vis;
    wire signed [9:0] bird_x, bird_y;
    wire [2:0] waiting;
    wire [NB*9-1:0] blk_x_f;
    wire [NB*8-1:0] blk_y_f;
    wire [NB-1:0] blk_horiz, blk_alive;
    wire [NP*9-1:0] pig_x_f;
    wire [NP*8-1:0] pig_y_f;
    wire [NP-1:0] pig_alive;
    wire [ND*9-1:0] dot_x_f;
    wire [ND*8-1:0] dot_y_f;
    wire [ND-1:0] dot_on;
    wire exp_on;
    wire [8:0] exp_x;
    wire [7:0] exp_y;
    wire [5:0] exp_r;
    wire [NB-1:0] blk_flash;
    wire [NP-1:0] pig_flash;

    game_logic #(.Num_blocks(NB), .Num_pigs(NP), .Num_dots(ND), .full_power(FULL_POWER)) g (
        .clk(clk), .reset(rst), .frame_tick(frame_tick), .key_press(key_press),
        .key_up(key_up), .key_down(key_down), .sw(sw), .power(power),
        .state(state), .level(level), .ptScreen_add(pts_add), .new_game(new_game), .game_end(game_end),
        .bird(bird), .bird_vis(bird_vis), .bird_x(bird_x), .bird_y(bird_y), .waiting(waiting),
        .blk_x_f(blk_x_f), .blk_y_f(blk_y_f), .blk_horiz(blk_horiz), .blk_alive(blk_alive),
        .pig_x_f(pig_x_f), .pig_y_f(pig_y_f), .pig_alive(pig_alive),
        .dot_x_f(dot_x_f), .dot_y_f(dot_y_f), .dot_on(dot_on),
        .exp_on(exp_on), .exp_x(exp_x), .exp_y(exp_y), .exp_r(exp_r),
        .blk_flash(blk_flash), .pig_flash(pig_flash));

    integer errors = 0;
    integer total_pts = 0;
    always @(posedge clk) if (!rst) total_pts = total_pts + pts_add;

    task frames(input integer n);
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                @(negedge clk) frame_tick = 1;
                @(negedge clk) frame_tick = 0;
                repeat (80) @(negedge clk);
            end
        end
    endtask

    task press;
        begin
            @(negedge clk) key_press = 1;
            @(negedge clk) key_press = 0;
            repeat (4) @(negedge clk);
        end
    endtask

    task goto_aim;
        integer guard;
        begin
            guard = 0;
            while (state != S_AIM && guard < 400) begin
                if (state == S_TITLE || state == S_OVER || state == S_WIN || state == S_CLEAR) press;
                else frames(1);
                guard = guard + 1;
            end
            if (state != S_AIM) begin
                errors = errors + 1;
                $display("  ERROR: never reached AIM (state=%0d)", state);
            end
        end
    endtask

    // replace the loaded level with one tower: block 0 on the ground, block 1 on top of it, pig 0 on top
    task build_tower;
        integer k;
        begin
            @(negedge clk);
            for (k = 0; k < NB; k = k + 1) begin
                g.block_x[k] = 9'd0;
                g.block_y[k] = 8'd0;
            end
            g.blk_alive = {NB{1'b0}};
            g.blk_horiz = {NB{1'b0}};
            g.pig_alive = {NP{1'b0}};
            g.block_x[0] = TOWER_X; g.block_y[0] = 8'd160;
            g.block_x[1] = TOWER_X; g.block_y[1] = 8'd120;
            g.blk_alive[1:0] = 2'b11;
            g.pig_x[0] = TOWER_X - 6; g.pig_y[0] = 8'd100;
            g.pig_fall_distance[0] = 6'd0;
            g.pig_alive[0] = 1'b1;
        end
    endtask

    // waits for the next collision and checks the freeze, the flash, the removal, health and points
    integer hit_count = 0;
    integer frozen_frames = 0;
    task expect_hit(input is_pig, input integer index, input last);
        integer guard, flash_n, remove_n, held_x, held_y, held_vx, held_vy, held_health, pts_before;
        reg [NB-1:0] want_blk;
        reg [NP-1:0] want_pig;
        begin
            hit_count = hit_count + 1;
            want_blk = is_pig ? {NB{1'b0}} : ({{NB-1{1'b0}}, 1'b1} << index);
            want_pig = is_pig ? ({{NP-1{1'b0}}, 1'b1} << index) : {NP{1'b0}};
            guard = 0;
            while (!g.col_pause && state == S_FLY && guard < 300) begin
                frames(1);
                guard = guard + 1;
            end
            if (!g.col_pause) begin
                errors = errors + 1;
                $display("  ERROR: hit %0d never happened (state=%0d bird=(%0d,%0d))", hit_count, state, bird_x, bird_y);
            end else begin
                held_x = bird_x; held_y = bird_y;
                held_vx = g.velocity_x; held_vy = g.velocity_y;
                held_health = g.col_health;
                pts_before = total_pts;
                $display("  hit %0d: %0s %0d at bird (%0d,%0d), health %0d", hit_count,
                         is_pig ? "pig" : "block", index, bird_x, bird_y, held_health);
                if (blk_flash !== want_blk || pig_flash !== want_pig) begin
                    errors = errors + 1;
                    $display("  ERROR: flash blk=%b pig=%b, expected blk=%b pig=%b", blk_flash, pig_flash, want_blk, want_pig);
                end

                flash_n = 0;
                while (g.collision_inst.col_state == C_FLASH && flash_n < 40) begin
                    if (bird_x !== held_x || bird_y !== held_y || g.velocity_y !== held_vy) begin
                        errors = errors + 1;
                        $display("  ERROR: bird moved during flash frame %0d: (%0d,%0d)", flash_n, bird_x, bird_y);
                    end
                    if (blk_flash !== want_blk || pig_flash !== want_pig || (blk_alive & want_blk) !== want_blk ||
                        (pig_alive & want_pig) !== want_pig) begin
                        errors = errors + 1;
                        $display("  ERROR: target not flashing or already gone on flash frame %0d", flash_n);
                    end
                    frames(1);
                    flash_n = flash_n + 1;
                end
                remove_n = 0;
                while (g.collision_inst.col_state == C_REMOVE && remove_n < 5) begin
                    if (bird_x !== held_x || bird_y !== held_y) begin
                        errors = errors + 1;
                        $display("  ERROR: bird moved during the remove frame");
                    end
                    if (g.col_spent !== last) begin
                        errors = errors + 1;
                        $display("  ERROR: spent=%b on the remove frame, expected %b", g.col_spent, last);
                    end
                    frames(1);
                    remove_n = remove_n + 1;
                end
                frozen_frames = flash_n + remove_n;
                $display("    flashed %0d frames, removed in %0d frame, frozen %0d frames, +%0d points",
                         flash_n, remove_n, frozen_frames, total_pts - pts_before);
                if (flash_n != FLASH_FRAMES || remove_n != 1) begin
                    errors = errors + 1;
                    $display("  ERROR: expected %0d flash frames and 1 remove frame", FLASH_FRAMES);
                end
                if ((blk_alive & want_blk) !== {NB{1'b0}} || (pig_alive & want_pig) !== {NP{1'b0}} ||
                    blk_flash !== {NB{1'b0}} || pig_flash !== {NP{1'b0}}) begin
                    errors = errors + 1;
                    $display("  ERROR: target not removed or still flashing");
                end
                if (total_pts - pts_before != (is_pig ? POINTS_PIG : POINTS_BLOCK)) begin
                    errors = errors + 1;
                    $display("  ERROR: %0d points, expected %0d", total_pts - pts_before, is_pig ? POINTS_PIG : POINTS_BLOCK);
                end
                if (last) begin
                    if (bird_vis || state != S_SETTLE) begin
                        errors = errors + 1;
                        $display("  ERROR: bird still flying after its last health (vis=%b state=%0d)", bird_vis, state);
                    end else
                        $display("    last health used: bird removed, game moves to SETTLE");
                end else begin
                    if (g.col_health !== held_health - 1) begin
                        errors = errors + 1;
                        $display("  ERROR: health %0d, expected %0d", g.col_health, held_health - 1);
                    end
                    if (state != S_FLY || g.col_pause || g.velocity_x !== held_vx || g.velocity_y !== held_vy + GRAVITY) begin
                        errors = errors + 1;
                        $display("  ERROR: flight did not resume with the same velocity (state=%0d v=(%0d,%0d), was (%0d,%0d))",
                                 state, g.velocity_x, g.velocity_y, held_vx, held_vy);
                    end else
                        $display("    flight resumed with the same velocity, health now %0d", g.col_health);
                end
            end
        end
    endtask

    initial begin
        g.horizontal_weight = 9'd181; // angle always @* reads only a constant, so it never runs in sim
        g.vertical_weight = 9'd181;
        repeat (5) @(negedge clk);
        rst = 0;
        repeat (5) @(negedge clk);

        goto_aim;
        build_tower;
        frames(3);
        if (blk_alive !== {{NB-2{1'b0}}, 2'b11} || pig_alive !== {{NP-1{1'b0}}, 1'b1} ||
            g.block_y[1] !== 8'd120 || g.pig_y[0] !== 8'd100) begin
            errors = errors + 1;
            $display("  ERROR: tower did not stay standing before the shot");
        end
        $display("Tower at x=%0d: pig 0 on block 1 on block 0. Power 0 shot, health %0d", TOWER_X, g.collision_inst.MAX_HEALTH);

        power = 4'd0;
        frames(2);
        press;
        expect_hit(1'b1, 0, 1'b0);
        expect_hit(1'b0, 1, 1'b0);
        expect_hit(1'b0, 0, 1'b1);

        if (errors == 0) $display("OBSTACLE PASS");
        else $display("OBSTACLE FAIL: %0d errors", errors);
        $stop;
    end
endmodule

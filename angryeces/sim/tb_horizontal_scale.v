`timescale 1ns / 1ps
// Horizontal arc scaling: slingshot power sets the x velocity and range, the arc height stays fixed. Ends with HORIZONTAL PASS / FAIL.
module tb_horizontal_scale;
    localparam NB = 12, NP = 3, ND = 10, FULL_POWER = 15;
    localparam [2:0] S_TITLE = 3'd0, S_LOAD = 3'd1, S_AIM = 3'd2, S_FLY = 3'd3,
                     S_SETTLE = 3'd4, S_CLEAR = 3'd5, S_OVER = 3'd6, S_WIN = 3'd7;
    localparam integer SLING_X = 40 * 64, SLING_Y = 158 * 64, GRAVITY = 4, SPEED_Y = 276;
    localparam integer CHECK_FRAME = 60; // bird_x is compared at this many frames into each flight

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

    function integer model_vx(input integer p);
        integer pc;
        begin
            pc = (p > 9) ? 9 : p;
            model_vx = ((96 + pc * 20) * 181) >> 8;
        end
    endfunction
    function integer model_vy0(input integer dummy);
        model_vy0 = -((SPEED_Y * 181) >> 8);
    endfunction
    function integer model_peak(input integer dummy); // highest point (smallest bird_y) at 1x vertical scale
        integer n, y, best;
        begin
            best = 999;
            for (n = 0; n < 300; n = n + 1) begin
                y = (SLING_Y + n * model_vy0(0) + (GRAVITY * n * (n - 1)) / 2) >>> 6;
                if (y < best) best = y;
            end
            model_peak = best;
        end
    endfunction

    integer errors = 0;
    integer peak_y = 999;
    always @(posedge clk)
        if (state == S_FLY && bird_vis && bird_y < peak_y) peak_y = bird_y;

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

    integer shot_vx, shot_x_check, shot_end_x, shot_peak;
    reg shot_left_screen;
    task shot(input integer p);
        integer guard;
        begin
            goto_aim;
            power = p;
            frames(2);
            if (g.launch_velocity_x !== model_vx(p) || g.launch_velocity_y !== model_vy0(0)) begin
                errors = errors + 1;
                $display("  ERROR: power %0d launch velocity=(%0d,%0d), expected (%0d,%0d)",
                         p, g.launch_velocity_x, g.launch_velocity_y, model_vx(p), model_vy0(0));
            end
            shot_vx = g.launch_velocity_x;

            peak_y = 999;
            press;
            frames(CHECK_FRAME);
            shot_x_check = bird_x;
            if (shot_x_check !== ((SLING_X + CHECK_FRAME * model_vx(p)) >>> 6)) begin
                errors = errors + 1;
                $display("  ERROR: power %0d bird_x=%0d after %0d frames, expected %0d",
                         p, shot_x_check, CHECK_FRAME, (SLING_X + CHECK_FRAME * model_vx(p)) >>> 6);
            end
            guard = 0;
            while (state == S_FLY && guard < 300) begin
                frames(1);
                guard = guard + 1;
            end
            shot_end_x = bird_x;
            shot_left_screen = !bird_vis;
            shot_peak = peak_y;
            if (shot_peak !== model_peak(0)) begin
                errors = errors + 1;
                $display("  ERROR: power %0d peak bird_y=%0d, expected %0d", p, shot_peak, model_peak(0));
            end
            $display("  power=%0d  vx=%3d  vy0=%0d  x@%0d=%3d  peak y=%0d  end x=%3d (%0s)",
                     p, shot_vx, g.launch_velocity_y, CHECK_FRAME, shot_x_check, shot_peak, shot_end_x,
                     shot_left_screen ? "left screen" : "landed");
        end
    endtask

    integer i, prev_vx, prev_x_check, prev_end_x;
    integer powers [0:3];
    initial begin
        powers[0] = 0; powers[1] = 3; powers[2] = 6; powers[3] = 9;
        g.horizontal_weight = 9'd181; // angle always @* reads only a constant, so it never runs in sim
        g.vertical_weight = 9'd181;
        force g.collision_inst.any_hit = 1'b0; // fly through the level so every arc is complete
        repeat (5) @(negedge clk);
        rst = 0;
        repeat (5) @(negedge clk);

        $display("Horizontal scaling: same launch angle, power 0 -> 9");
        prev_vx = -1; prev_x_check = -1; prev_end_x = -999;
        for (i = 0; i < 4; i = i + 1) begin
            shot(powers[i]);
            if (shot_vx <= prev_vx || shot_x_check <= prev_x_check || shot_end_x <= prev_end_x) begin
                errors = errors + 1;
                $display("  ERROR: power %0d did not travel further than the previous shot", powers[i]);
            end
            prev_vx = shot_vx; prev_x_check = shot_x_check; prev_end_x = shot_end_x;
        end

        if (errors == 0) $display("HORIZONTAL PASS");
        else $display("HORIZONTAL FAIL: %0d errors", errors);
        $stop;
    end
endmodule

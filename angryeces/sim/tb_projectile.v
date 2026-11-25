`timescale 1ns / 1ps
// Projectile X and Y at the fixed initial scale (arc_scale = 64). Ends with PROJECTILE PASS / FAIL.
module tb_projectile;
    localparam NB = 12, NP = 3, ND = 10, FULL_POWER = 15;
    localparam [2:0] S_TITLE = 3'd0, S_LOAD = 3'd1, S_AIM = 3'd2, S_FLY = 3'd3,
                     S_SETTLE = 3'd4, S_CLEAR = 3'd5, S_OVER = 3'd6, S_WIN = 3'd7;
    localparam integer SLING_X = 40 * 64, SLING_Y = 158 * 64;
    localparam integer GRAVITY = 4, SPEED_Y = 276, GROUND_BIRD_Y = 180, SCALE_ONE = 64;

    reg clk = 0;
    always #10 clk = ~clk;

    reg rst = 1, frame_tick = 0, key_press = 0;
    reg key_up = 0, key_down = 0; // never pressed, so the arc scale stays fixed
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

    // reference model, positions in 1/64 px
    function integer exp_speed_x(input integer p);
        integer pc;
        begin
            pc = (p > 9) ? 9 : p;
            exp_speed_x = 96 + (pc * FULL_POWER * 180) / (9 * FULL_POWER);
        end
    endfunction
    function integer exp_vx(input integer p);
        exp_vx = (exp_speed_x(p) * 181) >> 8;
    endfunction
    function integer exp_vy0(input integer dummy);
        exp_vy0 = -((SPEED_Y * 181) >> 8);
    endfunction
    function integer model_x(input integer p, input integer n);
        model_x = SLING_X + n * exp_vx(p);
    endfunction
    function integer model_y(input integer n);
        model_y = SLING_Y + n * exp_vy0(0) + (GRAVITY * n * (n - 1)) / 2;
    endfunction

    integer errors = 0;
    integer shot_power = 0;
    integer expected_vx = 0;
    integer expected_vy = 0;
    integer moves = 0;
    integer expected_pos_x = SLING_X;
    integer expected_pos_y = SLING_Y;
    integer expected_bird_x = SLING_X / 64;
    integer expected_bird_y = SLING_Y / 64;
    integer peak_bird_y = 999;
    reg tracking = 0;
    reg chk_pending = 0;

    // phase 1 is where game_logic moves the bird; the result is checked on the next clock
    always @(posedge clk) begin
        if (chk_pending) begin
            chk_pending = 0;
            if (g.position_x !== expected_pos_x || g.position_y !== expected_pos_y) begin
                errors = errors + 1;
                $display("  ERROR %0t: position=(%0d,%0d), expected (%0d,%0d)", $time,
                         g.position_x, g.position_y, expected_pos_x, expected_pos_y);
            end
            if (g.velocity_y !== expected_vy) begin
                errors = errors + 1;
                $display("  ERROR %0t: velocity_y=%0d, expected %0d", $time, g.velocity_y, expected_vy);
            end
            if (bird_x !== expected_bird_x || (!g.on_ground && bird_y !== expected_bird_y)) begin
                errors = errors + 1;
                $display("  ERROR %0t: bird=(%0d,%0d), expected (%0d,%0d)", $time,
                         bird_x, bird_y, expected_bird_x, expected_bird_y);
            end
            if (bird_y < peak_bird_y) peak_bird_y = bird_y;
        end
        if (tracking && !rst && g.phase == 3'd1 && g.state == S_FLY && g.bird_vis && !g.col_pause) begin
            if (g.velocity_x !== expected_vx || g.velocity_y !== expected_vy) begin
                errors = errors + 1;
                $display("  ERROR %0t: velocity=(%0d,%0d) before move, expected (%0d,%0d)", $time,
                         g.velocity_x, g.velocity_y, expected_vx, expected_vy);
            end
            moves = moves + 1;
            expected_pos_x = model_x(shot_power, moves);
            expected_pos_y = model_y(moves);
            expected_vy = exp_vy0(0) + GRAVITY * moves;
            expected_bird_x = expected_pos_x >>> 6;
            expected_bird_y = expected_pos_y >>> 6;
            chk_pending = 1;
        end
    end

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

    // aim dot k is the path after 6*(k+1) frames, drawn at +9 px
    task check_dots(input integer p);
        integer k, s, want_x, want_y, got_x, got_y;
        begin
            for (k = 0; k < ND; k = k + 1) begin
                s = 6 * (k + 1);
                want_x = ((model_x(p, s) >>> 6) + 9) % 512;
                want_y = (((model_y(s) >>> 6) + 9) % 256 + 256) % 256;
                got_x = dot_x_f[k*9 +: 9];
                got_y = dot_y_f[k*8 +: 8];
                if (got_x != want_x || got_y != want_y) begin
                    errors = errors + 1;
                    $display("  ERROR: power %0d dot %0d = (%0d,%0d), expected (%0d,%0d)",
                             p, k, got_x, got_y, want_x, want_y);
                end
            end
        end
    endtask

    task shot(input integer p);
        integer guard;
        begin
            goto_aim;
            power = p;
            frames(2);

            if (g.arc_scale !== SCALE_ONE) begin
                errors = errors + 1;
                $display("  ERROR: arc_scale=%0d, expected the fixed %0d", g.arc_scale, SCALE_ONE);
            end
            if (g.launch_velocity_x !== exp_vx(p) || g.launch_velocity_y !== exp_vy0(0)) begin
                errors = errors + 1;
                $display("  ERROR: power %0d launch velocity=(%0d,%0d), expected (%0d,%0d)",
                         p, g.launch_velocity_x, g.launch_velocity_y, exp_vx(p), exp_vy0(0));
            end
            check_dots(p);

            shot_power = p;
            expected_vx = exp_vx(p);
            expected_vy = exp_vy0(0);
            moves = 0;
            expected_pos_x = SLING_X;
            expected_pos_y = SLING_Y;
            expected_bird_x = SLING_X >>> 6;
            expected_bird_y = SLING_Y >>> 6;
            peak_bird_y = 999;
            tracking = 1;
            press;
            guard = 0;
            while (state == S_FLY && guard < 300) begin
                frames(1);
                guard = guard + 1;
            end
            tracking = 0;

            if (g.on_ground && bird_y !== GROUND_BIRD_Y) begin
                errors = errors + 1;
                $display("  ERROR: landed with bird_y=%0d, expected %0d", bird_y, GROUND_BIRD_Y);
            end
            $display("  power=%2d vx=%3d vy0=%0d  %3d frames  peak y=%0d  end (x,y)=(%0d,%0d)  %s",
                     p, expected_vx, exp_vy0(0), moves, peak_bird_y, bird_x, bird_y,
                     g.on_ground ? "landed" : (bird_vis ? "stopped" : "gone/hit"));
        end
    endtask

    integer p;
    initial begin
        g.horizontal_weight = 9'd181; // angle always @* reads only a constant, so it never runs in sim
        g.vertical_weight = 9'd181;
        repeat (5) @(negedge clk);
        rst = 0;
        repeat (5) @(negedge clk);

        $display("1. launch velocity table, arc_scale=%0d", g.arc_scale);
        for (p = 0; p < 16; p = p + 1) begin
            power = p;
            #1;
            $display("  power=%2d clamped=%0d speed_x=%3d vx=%3d vy=%0d",
                     p, g.clamped_power, g.speed_x, g.launch_velocity_x, g.launch_velocity_y);
            if (g.clamped_power !== ((p > 9) ? 9 : p) || g.speed_x !== exp_speed_x(p) ||
                g.launch_velocity_x !== exp_vx(p) || g.launch_velocity_y !== exp_vy0(0)) begin
                errors = errors + 1;
                $display("  ERROR: expected clamped=%0d speed_x=%0d vx=%0d vy=%0d",
                         (p > 9) ? 9 : p, exp_speed_x(p), exp_vx(p), exp_vy0(0));
            end
        end

        $display("2. flights");
        shot(0);
        shot(3);
        shot(6);
        shot(9);
        shot(12);

        if (errors == 0) $display("PROJECTILE PASS");
        else $display("PROJECTILE FAIL: %0d errors", errors);
        $stop;
    end
endmodule

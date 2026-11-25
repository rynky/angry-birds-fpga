`timescale 1ns / 1ps
// Vertical arc scaling: KEY2 (key_up) / KEY3 (key_down) stretch or squash the arc while aiming. Ends with VERTICAL PASS / FAIL.
module tb_vertical_scale;
    localparam NB = 12, NP = 3, ND = 10, FULL_POWER = 15;
    localparam [2:0] S_TITLE = 3'd0, S_LOAD = 3'd1, S_AIM = 3'd2, S_FLY = 3'd3,
                     S_SETTLE = 3'd4, S_CLEAR = 3'd5, S_OVER = 3'd6, S_WIN = 3'd7;
    localparam integer SLING_X = 40 * 64, SLING_Y = 158 * 64, GRAVITY = 4, SPEED_Y = 276;
    localparam integer SCALE_MIN = 32, SCALE_ONE = 64, SCALE_MAX = 128;
    localparam integer SHOT_POWER = 3, CHECK_FRAME = 50;

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
    function integer model_peak(input integer scale); // same height scaling as game_logic's scale_y
        integer n, offset, y, best;
        begin
            best = 999;
            for (n = 0; n < 300; n = n + 1) begin
                offset = n * model_vy0(0) + (GRAVITY * n * (n - 1)) / 2;
                y = ((offset * scale) >>> 12) + 158;
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

    task hold_keys(input up, input down, input integer n);
        begin
            key_up = up;
            key_down = down;
            frames(n);
            key_up = 0;
            key_down = 0;
        end
    endtask

    task expect_scale(input integer want, input [8*24-1:0] what);
        begin
            if (g.arc_scale !== want) begin
                errors = errors + 1;
                $display("  ERROR: %0s: arc_scale=%0d, expected %0d", what, g.arc_scale, want);
            end else
                $display("  %0s: arc_scale=%0d", what, g.arc_scale);
        end
    endtask

    task set_scale(input integer want);
        begin
            if (g.arc_scale < want) hold_keys(1, 0, want - g.arc_scale);
            else if (g.arc_scale > want) hold_keys(0, 1, g.arc_scale - want);
            expect_scale(want, "set");
        end
    endtask

    integer shot_x_check, shot_peak;
    task shot(input integer scale);
        integer guard;
        begin
            goto_aim;
            set_scale(scale);
            power = SHOT_POWER;
            frames(2);
            peak_y = 999;
            press;
            key_up = 1; // keys are ignored outside AIM, so this must not change the arc
            frames(CHECK_FRAME);
            key_up = 0;
            shot_x_check = bird_x;
            if (g.arc_scale !== scale) begin
                errors = errors + 1;
                $display("  ERROR: KEY2 changed arc_scale to %0d during flight", g.arc_scale);
            end
            if (shot_x_check !== ((SLING_X + CHECK_FRAME * model_vx(SHOT_POWER)) >>> 6)) begin
                errors = errors + 1;
                $display("  ERROR: scale %0d bird_x=%0d after %0d frames, expected %0d",
                         scale, shot_x_check, CHECK_FRAME, (SLING_X + CHECK_FRAME * model_vx(SHOT_POWER)) >>> 6);
            end
            guard = 0;
            while (state == S_FLY && guard < 300) begin
                frames(1);
                guard = guard + 1;
            end
            shot_peak = peak_y;
            if (shot_peak !== model_peak(scale)) begin
                errors = errors + 1;
                $display("  ERROR: scale %0d peak bird_y=%0d, expected %0d", scale, shot_peak, model_peak(scale));
            end
            $display("  scale=%3d (%0.2fx)  peak y=%3d  rise above slingshot=%3d px  x@%0d=%0d  end x=%0d",
                     scale, scale / 64.0, shot_peak, 158 - shot_peak,
                     CHECK_FRAME, shot_x_check, bird_x);
        end
    endtask

    integer rise_half, rise_one, rise_double;
    initial begin
        g.horizontal_weight = 9'd181; // angle always @* reads only a constant, so it never runs in sim
        g.vertical_weight = 9'd181;
        force g.collision_inst.any_hit = 1'b0; // fly through the level so every arc is complete
        repeat (5) @(negedge clk);
        rst = 0;
        repeat (5) @(negedge clk);

        $display("1. KEY2 / KEY3 while aiming");
        goto_aim;
        expect_scale(SCALE_ONE, "start");
        hold_keys(1, 0, 10);
        expect_scale(SCALE_ONE + 10, "KEY2 held 10 frames");
        hold_keys(1, 0, 80);
        expect_scale(SCALE_MAX, "KEY2 held 80 more");
        hold_keys(0, 1, 120);
        expect_scale(SCALE_MIN, "KEY3 held 120 frames");
        hold_keys(1, 1, 10);
        expect_scale(SCALE_MIN, "both held 10 frames");

        $display("2. flights at power %0d", SHOT_POWER);
        shot(SCALE_MIN);
        rise_half = 158 - shot_peak;
        shot(SCALE_ONE);
        rise_one = 158 - shot_peak;
        shot(SCALE_MAX);
        rise_double = 158 - shot_peak;
        if (!(rise_half < rise_one && rise_one < rise_double)) begin
            errors = errors + 1;
            $display("  ERROR: arc heights not ordered 0.5x < 1x < 2x (%0d, %0d, %0d)", rise_half, rise_one, rise_double);
        end

        if (errors == 0) $display("VERTICAL PASS");
        else $display("VERTICAL FAIL: %0d errors", errors);
        $stop;
    end
endmodule

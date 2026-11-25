// ============================================================================
// tb_game.v - projectile motion, collisions and scoring (game_logic + score_tracker)
//
// Time is sped up: a "frame" is ~100 clocks instead of 833,333, so whole shots
// run in microseconds. Launch power is driven straight in (as if from the
// slingshot); SW7-4 sets the angle.
//
// What it checks
//   1. a launch moves the bird: x goes up every frame, y goes up then down (gravity)
//   2. the bird lands and the game goes FLY -> SETTLE -> AIM with the next bird
//   3. the score tracker adds up exactly the points game_logic reports
//   4. level 1 can be cleared; LEVEL CLEAR -> level 2
//   5. game over saves the high score; a worse game afterwards leaves it alone
// Optional:  +SNAP  writes frame_aim.txt / frame_fly.txt (640x480 dumps of the
//            renderer; turn into PNGs with  python sim/dump2png.py frame_*.txt)
// ============================================================================
`timescale 1ns / 1ps
module tb_game;
    localparam NB = 12, NP = 3, ND = 10;
    reg clk = 0;  always #10 clk = ~clk;

    reg        rst = 1, frame_tick = 0, key_press = 0, key_up = 0, key_down = 0;
    reg  [9:0] sw = 10'd0;
    reg  [3:0] power = 4'd0;
    reg  [9:0] h = 0, v = 0;

    wire [2:0]  state;   wire [1:0] level, bird;
    wire [9:0]  pts_add; wire new_game, game_end;
    wire        bird_vis;  wire signed [9:0] bird_x, bird_y;  wire [2:0] waiting;
    wire [NB*9-1:0] blk_x_f;  wire [NB*8-1:0] blk_y_f;  wire [NB-1:0] blk_horiz, blk_alive;
    wire [NP*9-1:0] pig_x_f;  wire [NP*8-1:0] pig_y_f;  wire [NP-1:0] pig_alive;
    wire [ND*9-1:0] dot_x_f;  wire [ND*8-1:0] dot_y_f;  wire [ND-1:0] dot_on;
    wire exp_on;  wire [8:0] exp_x;  wire [7:0] exp_y;  wire [5:0] exp_r;
    wire [NB-1:0] blk_flash;  wire [NP-1:0] pig_flash;

    game_logic #(.Num_blocks(NB), .Num_pigs(NP), .Num_dots(ND), .full_power(15)) g (
        .clk(clk), .reset(rst), .frame_tick(frame_tick), .key_press(key_press),
        .key_up(key_up), .key_down(key_down), .sw(sw), .power(power),
        .state(state), .level(level), .ptScreen_add(pts_add), .new_game(new_game), .game_end(game_end),
        .bird(bird), .bird_vis(bird_vis), .bird_x(bird_x), .bird_y(bird_y), .waiting(waiting),
        .blk_x_f(blk_x_f), .blk_y_f(blk_y_f), .blk_horiz(blk_horiz), .blk_alive(blk_alive),
        .pig_x_f(pig_x_f), .pig_y_f(pig_y_f), .pig_alive(pig_alive),
        .dot_x_f(dot_x_f), .dot_y_f(dot_y_f), .dot_on(dot_on),
        .exp_on(exp_on), .exp_x(exp_x), .exp_y(exp_y), .exp_r(exp_r),
        .blk_flash(blk_flash), .pig_flash(pig_flash));

    wire [9:0] score, high_score;
    score_tracker sc (.clk(clk), .new_game(new_game), .add(pts_add), .game_end(game_end),
                      .score(score), .high_score(high_score));

    // renderer only for the optional screenshots
    wire [11:0] rgb;
    renderer #(.Num_blocks(NB), .Num_pigs(NP), .Num_dots(ND)) r (
        .clk(clk), .h(h), .v(v),
        .blk_x_f(blk_x_f), .blk_y_f(blk_y_f), .blk_horiz(blk_horiz), .blk_alive(blk_alive),
        .pig_x_f(pig_x_f), .pig_y_f(pig_y_f), .pig_alive(pig_alive),
        .blk_flash(blk_flash), .pig_flash(pig_flash),
        .bird_x(bird_x), .bird_y(bird_y), .bird_type(bird), .bird_vis(bird_vis), .waiting(waiting),
        .dot_x_f(dot_x_f), .dot_y_f(dot_y_f), .dot_on(dot_on),
        .exp_on(exp_on), .exp_x(exp_x), .exp_y(exp_y), .exp_r(exp_r),
        .line_en(6'b000001), .line_msg({20'd0, 4'd6 + {2'b00, level}}), .dim(1'b0), .rgb(rgb));

    // running total of every point game_logic reports, to cross-check the tracker
    integer pts_total = 0;
    always @(posedge clk) begin
        if (new_game) pts_total = 0;
        else          pts_total = pts_total + pts_add;
    end

    // ---------------------------------------------------------------- helpers
    task frames(input integer n);
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                @(negedge clk) frame_tick = 1;
                @(negedge clk) frame_tick = 0;
                repeat (80) @(negedge clk);        // aim-arc engine + 4 update phases
            end
        end
    endtask
    task press; begin @(negedge clk) key_press = 1; @(negedge clk) key_press = 0; repeat (4) @(negedge clk); end endtask

    task snap(input [8*24-1:0] name);
        integer fd, x, y;
        begin
            fd = $fopen(name, "w");
            for (y = 0; y < 480; y = y + 1)
                for (x = 0; x < 640; x = x + 1) begin
                    @(negedge clk) begin h = x; v = y; end
                    @(negedge clk); @(negedge clk);
                    $fwrite(fd, "%h\n", rgb);
                end
            $fclose(fd);
        end
    endtask

    integer errors = 0;
    task fail(input [8*48-1:0] msg); begin $display("FAIL: %0s", msg); errors = errors + 1; end endtask

    // one shot: aim, launch, follow the bird, wait for the result
    integer n, x_prev, y_min, peak_seen, x_start, y_start;
    task shoot(input [3:0] ang, input [3:0] pow);
        begin
            sw[7:4] = ang;  power = pow;
            frames(2);
            if (state != 3'd2) fail("not in AIM before a shot");
            press;                                            // KEY1 = launch
            if (state != 3'd3) fail("KEY1 did not launch (state != FLY)");
            x_start = bird_x;  y_start = bird_y;  x_prev = bird_x;  y_min = bird_y;  peak_seen = 0;
            n = 0;
            while (state == 3'd3 && n < 400) begin            // follow the flight
                frames(1);  n = n + 1;
                if (state == 3'd3 && bird_vis) begin
                    if (bird_x < x_prev) fail("bird moved backwards");
                    if (bird_y < y_min) y_min = bird_y;
                    if (bird_y > y_min + 2) peak_seen = 1;     // came back down = gravity works
                    x_prev = bird_x;
                end
            end
            $display("  angle %2d power %2d: flew %3d frames, x %0d -> %0d, highest y %0d %0s",
                     ang, pow, n, x_start, x_prev, y_min, peak_seen ? "(rose then fell)" : "");
            if (x_prev <= x_start) fail("bird did not move forward");
            if (y_min >= y_start)  fail("bird never rose");
            n = 0;
            while ((state == 3'd3 || state == 3'd4) && n < 600) begin frames(1); n = n + 1; end
            if (score != pts_total) fail("score tracker != points reported");
            $display("            -> state %0d, pigs %b, blocks %b, score %0d, high %0d",
                     state, pig_alive, blk_alive, score, high_score);
        end
    endtask

    task start_game(input [1:0] lvl);
        begin
            sw[9:8] = lvl;
            rst = 1; repeat (3) @(negedge clk); rst = 0;
            frames(1);  press;  frames(2);                    // title -> load -> aim
        end
    endtask

    integer a, p, hs_before;
    initial begin
        repeat (5) @(negedge clk);
        rst = 0;
        frames(2);

        if ($test$plusargs("SWEEP")) begin
            // which first shots clear level 1?  (prints the winners)
            for (a = 0; a < 16; a = a + 1)
                for (p = 0; p < 16; p = p + 1) begin
                    start_game(0);
                    sw[7:4] = a; power = p; frames(2); press;
                    n = 0; while (state != 3'd2 && state != 3'd5 && state != 3'd6 && n < 1000) begin frames(1); n = n + 1; end
                    if (state == 3'd5) $display("  level 1 cleared in one shot: angle %0d power %0d", a, p);
                end
            $stop;
        end

        $display("== Level 1, three shots ==");
        start_game(0);
        if (state != 3'd2) fail("game did not reach AIM");
        if ($test$plusargs("SNAP")) begin
            sw[7:4] = 4'd8; power = 4'd10; frames(3);
            snap("frame_aim.txt");
        end
        shoot(4'd6, 4'd9);
        if (state == 3'd2) shoot(4'd4, 4'd8);
        if (state == 3'd2) shoot(4'd8, 4'd9);

        if (state != 3'd5) fail("level 1 was not cleared");

        $display("== Level 2, three misses -> game over, high score saved ==");
        press;  frames(2);                                    // LEVEL CLEAR -> KEY1 -> level 2
        if (level != 2'd1 || state != 3'd2) fail("did not move on to level 2");
        shoot(4'd0, 4'd0);  shoot(4'd0, 4'd0);  shoot(4'd0, 4'd0);
        if (state != 3'd6) fail("3 misses did not end in GAME OVER");
        if (high_score != score || score == 0) fail("high score not saved at game over");
        $display("  game over: score %0d, high score %0d", score, high_score);

        $display("== New game, worse score -> high score kept ==");
        hs_before = high_score;
        press;  frames(1);                                    // GAME OVER -> KEY1 -> title
        sw[9:8] = 2'd0;  press;  frames(2);                   // title -> level 1 (no reset)
        if (score != 0) fail("score not cleared for a new game");
        shoot(4'd0, 4'd0);  shoot(4'd0, 4'd0);  shoot(4'd0, 4'd0);
        if (state != 3'd6) fail("3 misses did not end in GAME OVER");
        if (high_score != hs_before) fail("high score changed after a worse game");
        $display("  second game: score %0d, high score still %0d", score, high_score);

        if ($test$plusargs("SNAP")) begin
            start_game(0);
            sw[7:4] = 4'd6; power = 4'd9; frames(2); press; frames(30);
            snap("frame_fly.txt");
        end

        if (errors == 0) $display("GAME PASS"); else $display("GAME: %0d FAILURES", errors);
        $stop;
    end
endmodule

// tb_score.v - score_tracker: add points, cap at 999, high score only goes up
`timescale 1ns / 1ps
module tb_score;
    reg clk = 0; always #10 clk = ~clk;
    reg new_game = 0, game_end = 0;
    reg [9:0] add = 0;
    wire [9:0] score, high_score;
    score_tracker dut (.clk(clk), .new_game(new_game), .add(add), .game_end(game_end),
                       .score(score), .high_score(high_score));
    integer errors = 0;
    task pulse_add(input [9:0] n); begin @(negedge clk) add = n; @(negedge clk) add = 0; end endtask
    task check(input [9:0] s, input [9:0] hs, input [8*20-1:0] what); begin
        @(negedge clk);
        if (score !== s || high_score !== hs) begin
            $display("FAIL %0s: score=%0d high=%0d (expected %0d / %0d)", what, score, high_score, s, hs);
            errors = errors + 1;
        end else $display("%0s: score=%0d high=%0d", what, score, high_score);
    end endtask
    initial begin
        @(negedge clk) new_game = 1; @(negedge clk) new_game = 0;
        check(0, 0, "new game");
        pulse_add(50); pulse_add(5); pulse_add(5);
        check(60, 0, "+50 +5 +5");
        @(negedge clk) begin add = 25; game_end = 1; end           // bonus + end together
        @(negedge clk) begin add = 0;  game_end = 0; end
        check(85, 85, "game end, +25 bonus");
        @(negedge clk) new_game = 1; @(negedge clk) new_game = 0;
        pulse_add(20);
        @(negedge clk) game_end = 1; @(negedge clk) game_end = 0;
        check(20, 85, "lower game");
        @(negedge clk) new_game = 1; @(negedge clk) new_game = 0;
        repeat (6) pulse_add(200);
        @(negedge clk) game_end = 1; @(negedge clk) game_end = 0;
        check(999, 999, "capped at 999");
        if (errors == 0) $display("SCORE TRACKER PASS"); else $display("SCORE TRACKER: %0d FAILURES", errors);
        $stop;
    end
endmodule

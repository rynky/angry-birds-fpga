module score_tracker #(parameter WIDTH=10,parameter [WIDTH-1:0]MAX_SCORE=10'd999) (clk, new_game,add, game_end, score,high_score);
    input wire clk;
    input wire new_game;
    input wire [WIDTH-1:0] add; 
    input wire game_end; 
    output reg [WIDTH-1:0]score=0;
    output reg [WIDTH-1:0]high_score=0;

    wire [WIDTH:0] total_score=score+add;
    reg [WIDTH-1:0]next_score; 

    always @* begin
        if (total_score>MAX_SCORE)
            next_score= MAX_SCORE; 
        else
            next_score=total_score[WIDTH-1:0]; 

    end

    always @(posedge clk) begin
        if (new_game) begin
            score<=0;
        end 
        else begin
            score <=next_score; 
            if (game_end && next_score> high_score)
                high_score<=next_score;
        end

    end
endmodule

//lab code from Raiyan
module char_to_7seg(Q, HEX);
    input [3:0] Q;
    output [6:0] HEX;

    assign HEX[0]=(~Q[3]&~Q[2]&~Q[1]&Q[0])| (~Q[3]&Q[2]&~Q[1]&~Q[0])|(Q[3]&~Q[2]&Q[1]&Q[0]) |(Q[3]&Q[2]&~Q[1]&Q[0]);
    assign HEX[1]=(~Q[3]&Q[2]&~Q[1]&Q[0]) | (Q[2]&Q[1]&~Q[0]) | (Q[3]&Q[1]&Q[0]) | (Q[3]&Q[2]&~Q[0]);
    assign HEX[2]=(~Q[3]&~Q[2]&Q[1]&~Q[0])|(Q[3]&Q[2]&~Q[0]) | (Q[3]&Q[2]&Q[1]);
    assign HEX[3]=(~Q[3]&~Q[2]&~Q[1]&Q[0]) |(~Q[3]&Q[2]&~Q[1]&~Q[0]) | (Q[2]&Q[1]&Q[0]) | (Q[3]&~Q[2]&Q[1]&~Q[0]);
    assign HEX[4]=(~Q[3]&Q[0]) |(~Q[3]&Q[2]&~Q[1]) | (~Q[2]&~Q[1]&Q[0]);
    assign HEX[5]=(~Q[3]&~Q[2]&Q[0])|(~Q[3]&~Q[2]&Q[1]) | (~Q[3]&Q[1]&Q[0]) | (Q[3]&Q[2]&~Q[1]&Q[0]);
    assign HEX[6]=(~Q[3]&~Q[2]&~Q[1])| (~Q[3]&Q[2]&Q[1]&Q[0]) | (Q[3]&Q[2]&~Q[1]&~Q[0]);
endmodule

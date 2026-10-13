module part1_modified (
    input [1:0] SW,
    input [0:0] KEY,
    output [9:0] LEDR
);
    wire [8:0] state;
    wire z;

    sequence_modified_one_hot detector (
        .clk(KEY[0]),
        .reset_n(SW[0]),
        .w(SW[1]),
        .state(state),
        .z(z)
    );

    assign LEDR[8:0] = state;
    assign LEDR[9] = z;
endmodule

module sequence_modified_one_hot (
    input clk,
    input reset_n,
    input w,
    output [8:0] state,
    output z
);
    reg [8:0] y_Q;
    wire [8:0] Y_D;

    // Table 2: y0 is inverted; A is now 000000000.
    assign Y_D[0] = 1'b1;
    assign Y_D[1] = ~w & (~y_Q[0] | y_Q[5] | y_Q[6] | y_Q[7] | y_Q[8]);
    assign Y_D[2] = ~w & y_Q[1];
    assign Y_D[3] = ~w & y_Q[2];
    assign Y_D[4] = ~w & (y_Q[3] | y_Q[4]);
    assign Y_D[5] = w & (~y_Q[0] | y_Q[1] | y_Q[2] | y_Q[3] | y_Q[4]);
    assign Y_D[6] = w & y_Q[5];
    assign Y_D[7] = w & y_Q[6];
    assign Y_D[8] = w & (y_Q[7] | y_Q[8]);

    always @(posedge clk) begin
        y_Q <= !reset_n ? 9'b000000000 : Y_D;
    end

    assign state = y_Q;
    assign z = y_Q[4] | y_Q[8];
endmodule

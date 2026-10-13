module week5_part1 (
    input [0:0] KEY,
    input [1:0] SW,
    output [9:0] LEDR
);
    wire clk;
    wire reset_n;
    wire w;
    wire [8:0] d;
    reg [8:0] y;

    assign clk = ~KEY[0];
    assign reset_n = SW[0];
    assign w = SW[1];

    assign d[0] = ~reset_n;
    assign d[1] = reset_n & ~w & (y[0] | y[5] | y[6] | y[7] | y[8]);
    assign d[2] = reset_n & ~w & y[1];
    assign d[3] = reset_n & ~w & y[2];
    assign d[4] = reset_n & ~w & (y[3] | y[4]);
    assign d[5] = reset_n & w & (y[0] | y[1] | y[2] | y[3] | y[4]);
    assign d[6] = reset_n & w & y[5];
    assign d[7] = reset_n & w & y[6];
    assign d[8] = reset_n & w & (y[7] | y[8]);

    always @(posedge clk) begin
        y <= d;
    end

    assign LEDR[8:0] = y;
    assign LEDR[9] = y[4] | y[8];
endmodule

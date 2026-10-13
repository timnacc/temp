module part3 (
    input [1:0] SW,
    input [0:0] KEY,
    output [9:0] LEDR
);
    wire [3:0] ones;
    wire [3:0] zeros;
    wire z;

    sequence_shift detector (
        .clk(KEY[0]),
        .reset_n(SW[0]),
        .w(SW[1]),
        .ones(ones),
        .zeros(zeros),
        .z(z)
    );

    assign LEDR[3:0] = ones;
    assign LEDR[7:4] = zeros;
    assign LEDR[8] = 1'b0;
    assign LEDR[9] = z;
endmodule

module sequence_shift (
    input clk,
    input reset_n,
    input w,
    output reg [3:0] ones,
    output reg [3:0] zeros,
    output z
);
    // Each register collects matches: 1 for its target input, 0 otherwise.
    always @(posedge clk) begin
        ones  <= !reset_n ? 4'b0000 : {ones[2:0], w};
        zeros <= !reset_n ? 4'b0000 : {zeros[2:0], ~w};
    end

    // Reduction AND is true only when all four stored matches are 1.
    assign z = (&ones) | (&zeros);
endmodule

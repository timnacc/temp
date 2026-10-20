`timescale 1ns/1ps

module cm1 (
    input [7:0] X,
    output [7:0] Z
);
    // 7/32 = 1/8 + 1/16 + 1/32; no general multiplier is needed.
    assign Z = (X >> 3'd3) + (X >> 3'd4) + (X >> 3'd5);
endmodule

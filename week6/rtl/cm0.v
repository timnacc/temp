`timescale 1ns/1ps

module cm0 (
    input [7:0] X,
    output [7:0] Z
);
    // 35/128 = 1/4 + 1/64 + 1/128; each shift discards its low bits.
    assign Z = (X >> 3'd2) + (X >> 3'd6) + (X >> 3'd7);
endmodule

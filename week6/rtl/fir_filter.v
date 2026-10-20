`timescale 1ns/1ps

module fir_filter (
    input [7:0] X,
    input clk,
    input reset,
    output reg [7:0] Y
);
    reg [7:0] x_delay1;
    reg [7:0] x_delay2;
    wire [7:0] tap0;
    wire [7:0] tap1;
    wire [7:0] tap2;
    wire [9:0] sum;

    cm0 multiplier0 (.X(X), .Z(tap0));
    cm1 multiplier1 (.X(x_delay1), .Z(tap1));

    assign tap2 = x_delay2 >> 3'd1;
    assign sum = {2'b00, tap0} + {2'b00, tap1} + {2'b00, tap2};

    // Synchronous active-high reset has priority over sampling.
    always @(posedge clk) begin
        if (reset) begin
            x_delay1 <= 8'd0;
            x_delay2 <= 8'd0;
            Y <= 8'd0;
        end else begin
            x_delay1 <= X;
            x_delay2 <= x_delay1;
            // The largest possible sum is 67 + 53 + 127 = 247.
            Y <= sum[7:0];
        end
    end
endmodule

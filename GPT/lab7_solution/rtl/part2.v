module part2 (
    input [1:0] SW,
    input [0:0] KEY,
    output [9:0] LEDR
);
    wire [3:0] state;
    wire z;

    sequence_binary detector (
        .clk(KEY[0]),
        .reset_n(SW[0]),
        .w(SW[1]),
        .state(state),
        .z(z)
    );

    assign LEDR[3:0] = state;
    assign LEDR[8:4] = 5'b00000;
    assign LEDR[9] = z;
endmodule

module sequence_binary (
    input clk,
    input reset_n,
    input w,
    output [3:0] state,
    output z
);
    reg [3:0] y_Q;
    reg [3:0] Y_D;

    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010,
              D = 4'b0011, E = 4'b0100, F = 4'b0101,
              G = 4'b0110, H = 4'b0111, I = 4'b1000;

    always @(*) begin
        case (y_Q)
            A: Y_D = w ? F : B;
            B: Y_D = w ? F : C;
            C: Y_D = w ? F : D;
            D: Y_D = w ? F : E;
            E: Y_D = w ? F : E;
            F: Y_D = w ? G : B;
            G: Y_D = w ? H : B;
            H: Y_D = w ? I : B;
            I: Y_D = w ? I : B;
            default: Y_D = A;
        endcase
    end

    // Active-low synchronous reset, as required in Parts I and II.
    always @(posedge clk) begin
        y_Q <= !reset_n ? A : Y_D;
    end

    assign state = y_Q;
    assign z = (y_Q == E) | (y_Q == I);
endmodule

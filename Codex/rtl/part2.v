module week5_part2 (
    input [0:0] KEY,
    input [1:0] SW,
    output [9:0] LEDR
);
    localparam [3:0] A = 4'b0000;
    localparam [3:0] B = 4'b0001;
    localparam [3:0] C = 4'b0010;
    localparam [3:0] D = 4'b0011;
    localparam [3:0] E = 4'b0100;
    localparam [3:0] F = 4'b0101;
    localparam [3:0] G = 4'b0110;
    localparam [3:0] H = 4'b0111;
    localparam [3:0] I = 4'b1000;

    wire clk;
    wire reset_n;
    wire w;
    wire z;
    reg [3:0] y_Q;
    reg [3:0] Y_D;

    assign clk = ~KEY[0];
    assign reset_n = SW[0];
    assign w = SW[1];

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

    always @(posedge clk) begin
        if (!reset_n)
            y_Q <= A;
        else
            y_Q <= Y_D;
    end

    assign z = (y_Q == E) | (y_Q == I);
    assign LEDR = {z, 5'b00000, y_Q};
endmodule

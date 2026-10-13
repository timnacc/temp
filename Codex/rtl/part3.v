module week5_part3 (
    input [0:0] KEY,
    input [1:0] SW,
    output [9:0] LEDR
);
    wire clk;
    wire reset_n;
    wire w;
    wire z;
    reg [3:0] zeros;
    reg [3:0] ones;

    assign clk = ~KEY[0];
    assign reset_n = SW[0];
    assign w = SW[1];

    always @(posedge clk) begin
        if (!reset_n) begin
            zeros <= 4'b0000;
            ones <= 4'b0000;
        end else begin
            zeros <= {zeros[2:0], ~w};
            ones <= {ones[2:0], w};
        end
    end

    assign z = (&zeros) | (&ones);
    assign LEDR = {z, 1'b0, ones, zeros};
endmodule

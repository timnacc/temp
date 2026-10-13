// Optional answer to the Part III question; part3.v is the required design.
module sequence_single_shift (
    input clk,
    input reset_n,
    input w,
    output reg [3:0] history,
    output z
);
    reg [2:0] samples;

    // The window becomes valid after four real samples, not reset padding.
    always @(posedge clk) begin
        if (!reset_n) begin
            history <= 4'b0000;
            samples <= 3'd0;
        end else begin
            history <= {history[2:0], w};
            samples <= (samples < 3'd4) ? samples + 3'd1 : samples;
        end
    end

    assign z = (samples == 3'd4) & ((&history) | (~|history));
endmodule

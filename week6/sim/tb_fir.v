`timescale 1ns/1ps

module tb_fir;
    reg clk;
    reg reset;
    reg [7:0] X;
    reg [7:0] multiplier_input;
    wire [7:0] Y;
    wire [7:0] combined_y;
    wire [7:0] product0;
    wire [7:0] product1;
    reg [7:0] old_y;
    reg [15:0] random_state;
    integer previous1;
    integer previous2;
    integer expected;
    integer cycles;
    integer value;

    fir_filter uut (.X(X), .clk(clk), .reset(reset), .Y(Y));
    fir_filter_combined combined (.X(X), .clk(clk), .reset(reset), .Y(combined_y));
    cm0 test_cm0 (.X(multiplier_input), .Z(product0));
    cm1 test_cm1 (.X(multiplier_input), .Z(product1));

    always #5 clk = ~clk;

    task sample;
        input reset_value;
        input [7:0] input_value;
        begin
            @(negedge clk);
            old_y = Y;
            reset = reset_value;
            X = input_value;
            #1;
            if (Y !== old_y)
                $fatal(1, "Y changed without a rising edge at cycle %0d", cycles);
            if (combined_y !== old_y)
                $fatal(1, "Combined Y changed without a rising edge at cycle %0d", cycles);

            if (reset_value) begin
                expected = 0;
                previous1 = 0;
                previous2 = 0;
            end else begin
                // Integer division is an independent model of unsigned shifts.
                expected = input_value / 4 + input_value / 64 + input_value / 128
                         + previous1 / 8 + previous1 / 16 + previous1 / 32
                         + previous2 / 2;
                previous2 = previous1;
                previous1 = input_value;
            end

            @(posedge clk);
            #1;
            if (Y !== expected[7:0])
                $fatal(1, "Cycle %0d: X=%0d, Y=%0d, expected=%0d",
                       cycles, input_value, Y, expected);
            if (combined_y !== Y)
                $fatal(1, "Combined filter differs at cycle %0d", cycles);
            if (uut.sum > 10'd247 || combined.sum > 10'd247)
                $fatal(1, "Sum exceeded the proven output bound");
            cycles = cycles + 1;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        X = 8'd0;
        multiplier_input = 8'd0;
        previous1 = 0;
        previous2 = 0;
        cycles = 0;
        random_state = 16'hACE1;

        for (value = 0; value < 256; value = value + 1) begin
            multiplier_input = value[7:0];
            #1;
            expected = value / 4 + value / 64 + value / 128;
            if (product0 !== expected[7:0])
                $fatal(1, "cm0 mismatch for %0d", value);
            expected = value / 8 + value / 16 + value / 32;
            if (product1 !== expected[7:0])
                $fatal(1, "cm1 mismatch for %0d", value);
        end

        sample(1'b1, 8'd255);
        sample(1'b0, 8'd128);
        sample(1'b0, 8'd0);
        sample(1'b0, 8'd0);
        sample(1'b0, 8'd0);

        for (value = 0; value < 256; value = value + 1)
            sample(1'b0, value[7:0]);
        for (value = 0; value < 16; value = value + 1)
            sample(1'b0, 8'd255);
        for (value = 0; value < 256; value = value + 1)
            sample(1'b0, value[0] ? 8'd255 : 8'd0);

        // Reset a populated delay chain, then verify both old samples were cleared.
        sample(1'b1, 8'd255);
        sample(1'b1, 8'd255);
        sample(1'b0, 8'd0);
        sample(1'b0, 8'd0);
        sample(1'b0, 8'd0);

        for (value = 0; value < 4096; value = value + 1) begin
            random_state = {random_state[14:0], random_state[15] ^ random_state[13]
                          ^ random_state[12] ^ random_state[10]};
            sample(1'b0, random_state[7:0]);
        end

        $display("PASS: all 256 inputs of cm0/cm1; %0d FIR cycles, reset, impulse, bounds, and history.", cycles);
        $display("PASS: combined filter matches the modular filter on every checked cycle.");
        $finish;
    end
endmodule

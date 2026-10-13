`timescale 1ns/1ps

module tb_sequences;
    reg [0:0] KEY;
    reg [1:0] SW;
    wire [9:0] led_onehot;
    wire [9:0] led_modified;
    wire [9:0] led_binary;
    wire [9:0] led_shift;
    reg previous_bit;
    reg expected_z;
    reg [8:0] expected_onehot;
    reg [3:0] expected_state;
    reg [3:0] expected_zeros;
    reg [3:0] expected_ones;
    integer run_length;
    integer pattern;
    integer bit_index;
    integer cycles;

    week5_part1 onehot (.KEY(KEY), .SW(SW), .LEDR(led_onehot));
    week5_part1_modified modified (.KEY(KEY), .SW(SW), .LEDR(led_modified));
    week5_part2 binary_fsm (.KEY(KEY), .SW(SW), .LEDR(led_binary));
    week5_part3 shift_detector (.KEY(KEY), .SW(SW), .LEDR(led_shift));

    task sample;
        input reset_active;
        input symbol;
        reg [39:0] old_outputs;
        begin
            old_outputs = {led_onehot, led_modified, led_binary, led_shift};
            SW = {symbol, ~reset_active};
            #1;
            if ({led_onehot, led_modified, led_binary, led_shift} !== old_outputs)
                $fatal(1, "Output changed without a clock edge");

            if (reset_active) begin
                run_length = 0;
                expected_state = 4'd0;
                expected_zeros = 4'b0000;
                expected_ones = 4'b0000;
            end else begin
                if (run_length == 0 || symbol != previous_bit)
                    run_length = 1;
                else if (run_length < 4)
                    run_length = run_length + 1;
                expected_state = symbol ? run_length + 4 : run_length;
                expected_zeros = {expected_zeros[2:0], ~symbol};
                expected_ones = {expected_ones[2:0], symbol};
            end
            previous_bit = symbol;
            expected_z = (run_length == 4);
            expected_onehot = 9'b000000001 << expected_state;

            KEY[0] = 1'b0;
            #1;
            if (led_onehot !== {expected_z, expected_onehot})
                $fatal(1, "One-hot mismatch at sample %0d", cycles);
            if (led_modified !== {expected_z, (expected_onehot ^ 9'b000000001)})
                $fatal(1, "Modified one-hot mismatch at sample %0d", cycles);
            if (led_binary !== {expected_z, 5'b00000, expected_state})
                $fatal(1, "Binary FSM mismatch at sample %0d", cycles);
            if (led_shift !== {expected_z, 1'b0, expected_ones, expected_zeros})
                $fatal(1, "Shift detector mismatch at sample %0d", cycles);

            old_outputs = {led_onehot, led_modified, led_binary, led_shift};
            KEY[0] = 1'b1;
            #1;
            if ({led_onehot, led_modified, led_binary, led_shift} !== old_outputs)
                $fatal(1, "Output changed on button release");
            cycles = cycles + 1;
        end
    endtask

    initial begin
        KEY = 1'b1;
        SW = 2'b00;
        previous_bit = 1'b0;
        run_length = 0;
        expected_zeros = 4'b0000;
        expected_ones = 4'b0000;
        cycles = 0;
        #1;

        for (pattern = 0; pattern < 4096; pattern = pattern + 1) begin
            sample(1'b1, pattern[0]);
            for (bit_index = 11; bit_index >= 0; bit_index = bit_index - 1)
                sample(1'b0, pattern[bit_index]);
        end

        sample(1'b1, 1'b0);
        SW[0] = 1'b1;
        binary_fsm.y_Q = 4'd15;
        #1;
        KEY[0] = 1'b0;
        #1;
        if (led_binary !== 10'd0)
            $fatal(1, "Invalid binary state did not return to A");
        KEY[0] = 1'b1;
        #1;

        $display("PASS: %0d sequence samples; all 4096 twelve-bit sequences, encodings, synchronous reset, and button edges.", cycles);
        $finish;
    end
endmodule

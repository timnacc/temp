`timescale 1ns/1ps
module tb_sequence;
    reg clk;
    reg reset_n;
    reg w;
    wire [1:0] SW;
    wire [0:0] KEY;
    wire [9:0] led1, led1m, led2, led3;
    wire [3:0] history;
    wire z_single;
    integer pattern;
    integer bit_number;
    integer run_length;
    integer expected_state;
    integer samples;
    reg previous_w;
    reg expected_z;
    reg [8:0] expected_one_hot;

    assign SW = {w, reset_n};
    assign KEY[0] = clk;
    part1 p1 (.SW(SW), .KEY(KEY), .LEDR(led1));
    part1_modified p1m (.SW(SW), .KEY(KEY), .LEDR(led1m));
    part2 p2 (.SW(SW), .KEY(KEY), .LEDR(led2));
    part3 p3 (.SW(SW), .KEY(KEY), .LEDR(led3));
    sequence_single_shift single_detector (
        .clk(clk), .reset_n(reset_n), .w(w),
        .history(history), .z(z_single)
    );

    task clock_once;
        begin
            #5 clk = 1'b1;
            #1;
            #4 clk = 1'b0;
        end
    endtask

    task reset_all;
        begin
            reset_n = 1'b0;
            clock_once;
            if (led1 !== 10'b0000000001 || led1m !== 10'd0 ||
                led2 !== 10'd0 || led3 !== 10'd0 || z_single !== 1'b0) begin
                $display("FAIL: reset outputs");
                $finish;
            end
            reset_n = 1'b1;
            run_length = 0;
            previous_w = 1'b0;
        end
    endtask

    task apply_sample;
        input sample;
        begin
            w = sample;
            if (run_length == 0 || w != previous_w)
                run_length = 1;
            else
                run_length = run_length + 1;
            previous_w = w;
            expected_z = (run_length >= 4);
            expected_state = (run_length >= 4) ? 4 : run_length;
            if (w) expected_state = expected_state + 4;
            expected_one_hot = 9'b000000001 << expected_state;
            clock_once;
            if (led1[8:0] !== expected_one_hot ||
                led1m[8:0] !== (expected_one_hot ^ 9'b000000001) ||
                led2[3:0] !== expected_state[3:0] ||
                led1[9] !== expected_z || led1m[9] !== expected_z ||
                led2[9] !== expected_z || led3[9] !== expected_z ||
                z_single !== expected_z) begin
                $display("FAIL: pattern=%0d bit=%0d w=%b run=%0d", pattern, bit_number, w, run_length);
                $finish;
            end
            samples = samples + 1;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset_n = 1'b1;
        w = 1'b0;
        samples = 0;
        // Every 12-bit sequence, including every shorter sequence as a prefix.
        for (pattern = 0; pattern < 4096; pattern = pattern + 1) begin
            reset_all;
            for (bit_number = 11; bit_number >= 0; bit_number = bit_number - 1)
                apply_sample((pattern >> bit_number) & 1);
        end
        reset_all;
        for (bit_number = 0; bit_number < 32; bit_number = bit_number + 1)
            apply_sample(1'b0);
        for (bit_number = 0; bit_number < 32; bit_number = bit_number + 1)
            apply_sample(1'b1);
        // Changing the synchronous reset between edges must not reset yet.
        reset_n = 1'b0;
        #2;
        if (led1[9] !== 1'b1 || led1m[9] !== 1'b1 ||
            led2[9] !== 1'b1 || led3[9] !== 1'b1 || z_single !== 1'b1) begin
            $display("FAIL: reset acted asynchronously");
            $finish;
        end
        reset_all;
        $display("PASS: five detector designs; 4096 exhaustive sequences; %0d samples; synchronous reset", samples);
        $finish;
    end
endmodule

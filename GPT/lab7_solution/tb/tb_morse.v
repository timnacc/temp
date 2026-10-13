`timescale 1ns/1ps
module tb_morse;
    parameter HALF = 8;
    reg clk;
    reg reset_n;
    reg start_n;
    reg [2:0] letter;
    wire led;
    reg [3:0] expected_code;
    integer expected_length;
    integer letter_number;
    integer symbol_number;
    integer cycles;
    integer expected_cycles;
    integer timeout;
    integer checks;

    morse_encoder #(.HALF_SECOND_CYCLES(25'd8)) dut (
        .clk(clk), .reset_n(reset_n), .start_n(start_n),
        .letter(letter), .led(led)
    );
    always #5 clk = ~clk;

    task step;
        begin @(posedge clk); #1; end
    endtask

    task idle_check;
        input integer duration;
        integer j;
        begin
            for (j = 0; j < duration; j = j + 1) begin
                step;
                if (led !== 1'b0) begin
                    $display("FAIL: unexpected transmission while idle");
                    $finish;
                end
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset_n = 1'b0;
        start_n = 1'b1;
        letter = 3'd0;
        checks = 0;
        step;
        @(negedge clk); reset_n = 1'b1;
        idle_check(5);

        for (letter_number = 0; letter_number < 8; letter_number = letter_number + 1) begin
            case (letter_number)
                0: begin expected_code = 4'b0100; expected_length = 2; end
                1: begin expected_code = 4'b1000; expected_length = 4; end
                2: begin expected_code = 4'b1010; expected_length = 4; end
                3: begin expected_code = 4'b1000; expected_length = 3; end
                4: begin expected_code = 4'b0000; expected_length = 1; end
                5: begin expected_code = 4'b0010; expected_length = 4; end
                6: begin expected_code = 4'b1100; expected_length = 3; end
                7: begin expected_code = 4'b0000; expected_length = 4; end
            endcase
            @(negedge clk);
            letter = letter_number[2:0];
            start_n = 1'b0;
            timeout = 0;
            while (led !== 1'b1 && timeout < 10) begin
                step;
                timeout = timeout + 1;
            end
            if (led !== 1'b1) begin
                $display("FAIL: start press was not accepted"); $finish;
            end
            // Switch changes must not alter the already loaded letter.
            letter = ~letter_number[2:0];

            for (symbol_number = 0; symbol_number < expected_length; symbol_number = symbol_number + 1) begin
                expected_cycles = expected_code[3-symbol_number] ? 3*HALF : HALF;
                cycles = 0;
                while (led === 1'b1 && cycles < 4*HALF) begin
                    cycles = cycles + 1;
                    // B: release and press again during its first dash.
                    if (letter_number == 1 && symbol_number == 0) begin
                        if (cycles == 2) start_n = 1'b1;
                        if (cycles == 7) start_n = 1'b0;
                    end
                    step;
                end
                if (cycles != expected_cycles || led !== 1'b0) begin
                    $display("FAIL: letter=%0d symbol=%0d high=%0d expected=%0d", letter_number, symbol_number, cycles, expected_cycles);
                    $finish;
                end
                checks = checks + 1;
                if (symbol_number < expected_length - 1) begin
                    cycles = 0;
                    while (led === 1'b0 && cycles < 2*HALF) begin
                        cycles = cycles + 1;
                        step;
                    end
                    if (cycles != HALF || led !== 1'b1) begin
                        $display("FAIL: letter=%0d gap=%0d", letter_number, cycles);
                        $finish;
                    end
                end
            end
            // A held start button must not retrigger after completion.
            idle_check(4*HALF);
            @(negedge clk); start_n = 1'b1;
            idle_check(5);
        end

        // Abort an active dash without waiting for the next clock edge.
        @(negedge clk); letter = 3'd1; start_n = 1'b0;
        timeout = 0;
        while (led !== 1'b1 && timeout < 10) begin step; timeout = timeout + 1; end
        if (led !== 1'b1) begin $display("FAIL: reset test never started"); $finish; end
        @(negedge clk); #1 reset_n = 1'b0; #1;
        if (led !== 1'b0) begin $display("FAIL: reset was not asynchronous"); $finish; end
        start_n = 1'b1;
        step;
        @(negedge clk); reset_n = 1'b1;
        idle_check(4*HALF);
        $display("PASS: A-H; %0d symbols; exact dot/dash/gap durations; latched letter; held/busy start; asynchronous reset", checks);
        $finish;
    end
endmodule

`timescale 1ns/1ps

module tb_morse;
    parameter [24:0] TICK_CYCLES = 25'd4;
    reg CLOCK_50;
    reg [1:0] KEY;
    reg [2:0] SW;
    wire [9:0] LEDR;
    reg inject_busy_press;
    integer busy_cycles;
    integer letter;
    integer letters_checked;

    week5_part4 #(.HALF_SECOND_CYCLES(TICK_CYCLES)) dut (
        .CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .LEDR(LEDR)
    );

    task clock_tick;
        begin
            if (inject_busy_press) begin
                busy_cycles = busy_cycles + 1;
                if (busy_cycles == 2) KEY[1] = 1'b1;
                if (busy_cycles == 5) KEY[1] = 1'b0;
            end
            #4;
            CLOCK_50 = 1'b1;
            #1;
            if (LEDR[9:1] !== 9'd0)
                $fatal(1, "Unused Morse LEDs were not off");
            #4;
            CLOCK_50 = 1'b0;
            #1;
        end
    endtask

    task reset_encoder;
        begin
            inject_busy_press = 1'b0;
            KEY = 2'b10;
            #1;
            if (LEDR !== 10'd0 || dut.timer !== 25'd0 || dut.remaining !== 3'd0)
                $fatal(1, "Asynchronous reset failed without a clock");
            KEY[0] = 1'b1;
            repeat (4) clock_tick;
        end
    endtask

    task start_letter;
        input [2:0] selection;
        integer latency;
        begin
            SW = selection;
            KEY[1] = 1'b1;
            repeat (4) clock_tick;
            KEY[1] = 1'b0;
            latency = 0;
            while (LEDR[0] !== 1'b1 && latency < 8) begin
                clock_tick;
                latency = latency + 1;
            end
            if (LEDR[0] !== 1'b1)
                $fatal(1, "Letter %0d did not start", selection);
        end
    endtask

    task symbol;
        input integer duration;
        input last_symbol;
        integer cycle;
        begin
            if (LEDR[0] !== 1'b1)
                $fatal(1, "Expected symbol to begin on");
            for (cycle = 1; cycle < duration * TICK_CYCLES; cycle = cycle + 1) begin
                clock_tick;
                if (LEDR[0] !== 1'b1)
                    $fatal(1, "Pulse ended early: letter %0d", letter);
            end
            clock_tick;
            if (LEDR[0] !== 1'b0)
                $fatal(1, "Pulse ended late: letter %0d", letter);

            if (!last_symbol) begin
                for (cycle = 1; cycle < TICK_CYCLES; cycle = cycle + 1) begin
                    clock_tick;
                    if (LEDR[0] !== 1'b0)
                        $fatal(1, "Gap ended early: letter %0d", letter);
                end
                clock_tick;
                if (LEDR[0] !== 1'b1)
                    $fatal(1, "Gap ended late: letter %0d", letter);
            end
        end
    endtask

    task check_letter;
        input [2:0] selection;
        input busy_press;
        integer idle_cycle;
        begin
            reset_encoder;
            letter = selection;
            start_letter(selection);
            SW = ~selection;
            inject_busy_press = busy_press;
            busy_cycles = 0;

            case (selection)
                3'd0: begin symbol(1, 0); symbol(3, 1); end
                3'd1: begin symbol(3, 0); symbol(1, 0); symbol(1, 0); symbol(1, 1); end
                3'd2: begin symbol(3, 0); symbol(1, 0); symbol(3, 0); symbol(1, 1); end
                3'd3: begin symbol(3, 0); symbol(1, 0); symbol(1, 1); end
                3'd4: begin symbol(1, 1); end
                3'd5: begin symbol(1, 0); symbol(1, 0); symbol(3, 0); symbol(1, 1); end
                3'd6: begin symbol(3, 0); symbol(3, 0); symbol(1, 1); end
                3'd7: begin symbol(1, 0); symbol(1, 0); symbol(1, 0); symbol(1, 1); end
            endcase

            inject_busy_press = 1'b0;
            for (idle_cycle = 0; idle_cycle < 5 * TICK_CYCLES + 8; idle_cycle = idle_cycle + 1) begin
                clock_tick;
                if (LEDR[0] !== 1'b0)
                    $fatal(1, "Held start or busy press retriggered playback");
            end
            letters_checked = letters_checked + 1;
        end
    endtask

    initial begin
        CLOCK_50 = 1'b0;
        KEY = 2'b11;
        SW = 3'd0;
        inject_busy_press = 1'b0;
        busy_cycles = 0;
        letters_checked = 0;
        #1;

        for (letter = 0; letter < 8; letter = letter + 1)
            check_letter(letter[2:0], 1'b0);
        check_letter(3'd2, 1'b1);

        reset_encoder;
        start_letter(3'd7);
        reset_encoder;
        start_letter(3'd7);
        repeat (TICK_CYCLES) clock_tick;
        if (LEDR[0] !== 1'b0 || dut.state !== 2'd2)
            $fatal(1, "Expected gap before reset test");
        reset_encoder;

        start_letter(3'd4);
        symbol(1, 1);
        start_letter(3'd4);
        symbol(1, 1);

        $display("PASS: %0d Morse playbacks at %0d clocks per half-second; exact pulses/gaps, captured selection, held/busy start, asynchronous reset, and restart.", letters_checked, TICK_CYCLES);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Morse simulation timed out");
    end
endmodule

module part4 (
    input CLOCK_50,
    input [2:0] SW,
    input [1:0] KEY,
    output [9:0] LEDR
);
    wire morse_led;

    morse_encoder encoder (
        .clk(CLOCK_50),
        .reset_n(KEY[0]),
        .start_n(KEY[1]),
        .letter(SW[2:0]),
        .led(morse_led)
    );

    assign LEDR[0] = morse_led;
    assign LEDR[9:1] = 9'b000000000;
endmodule

module morse_letter (
    input [2:0] letter,
    output reg [3:0] code,
    output reg [2:0] length
);
    // Send bit 3 first: dot=0, dash=1; unused low bits are padding.
    always @(*) begin
        case (letter)
            3'd0: begin code = 4'b0100; length = 3'd2; end // A .-
            3'd1: begin code = 4'b1000; length = 3'd4; end // B -...
            3'd2: begin code = 4'b1010; length = 3'd4; end // C -.-.
            3'd3: begin code = 4'b1000; length = 3'd3; end // D -..
            3'd4: begin code = 4'b0000; length = 3'd1; end // E .
            3'd5: begin code = 4'b0010; length = 3'd4; end // F ..-.
            3'd6: begin code = 4'b1100; length = 3'd3; end // G --.
            3'd7: begin code = 4'b0000; length = 3'd4; end // H ....
            default: begin code = 4'b0000; length = 3'd1; end
        endcase
    end
endmodule

module half_second_timer #(
    parameter [24:0] HALF_SECOND_CYCLES = 25'd25000000
) (
    input clk,
    input reset_n,
    input clear,
    output tick
);
    reg [24:0] count;

    assign tick = (count == HALF_SECOND_CYCLES - 25'd1);

    // clear starts a fresh interval; tick is a clock enable, not a clock.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            count <= 25'd0;
        else
            count <= (clear | tick) ? 25'd0 : count + 25'd1;
    end
endmodule

module morse_encoder #(
    parameter [24:0] HALF_SECOND_CYCLES = 25'd25000000
) (
    input clk,
    input reset_n,
    input start_n,
    input [2:0] letter,
    output led
);
    parameter IDLE = 3'd0, PULSE1 = 3'd1, PULSE2 = 3'd2,
              PULSE3 = 3'd3, GAP = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] morse;
    reg [2:0] remaining;
    reg start_meta;
    reg start_sync;
    reg start_previous;

    wire [3:0] letter_code;
    wire [2:0] letter_length;
    wire start_press;
    wire load;
    wire shift;
    wire tick;

    morse_letter selection (
        .letter(letter),
        .code(letter_code),
        .length(letter_length)
    );

    half_second_timer #(
        .HALF_SECOND_CYCLES(HALF_SECOND_CYCLES)
    ) timer (
        .clk(clk),
        .reset_n(reset_n),
        .clear(state == IDLE),
        .tick(tick)
    );

    // Synchronize KEY1, then detect its active-low press once.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            start_meta <= 1'b1;
            start_sync <= 1'b1;
            start_previous <= 1'b1;
        end else begin
            start_meta <= start_n;
            start_sync <= start_meta;
            start_previous <= start_sync;
        end
    end

    assign start_press = start_previous & ~start_sync;
    assign load = (state == IDLE) & start_press;
    assign shift = (state == GAP) & tick;

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: next_state = start_press ? PULSE1 : IDLE;
            PULSE1: begin
                if (tick) begin
                    if (morse[3])
                        next_state = PULSE2;
                    else
                        next_state = (remaining == 3'd1) ? IDLE : GAP;
                end
            end
            PULSE2: next_state = tick ? PULSE3 : PULSE2;
            PULSE3: begin
                if (tick)
                    next_state = (remaining == 3'd1) ? IDLE : GAP;
            end
            GAP: next_state = tick ? PULSE1 : GAP;
            default: next_state = IDLE;
        endcase
    end

    // Load priority precedes shift. The selected letter is latched once.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            morse <= 4'b0000;
            remaining <= 3'd0;
        end else begin
            state <= next_state;
            if (load) begin
                morse <= letter_code;
                remaining <= letter_length;
            end else if (shift) begin
                morse <= {morse[2:0], 1'b0};
                remaining <= remaining - 3'd1;
            end
        end
    end

    // One high interval for a dot; three contiguous high intervals for a dash.
    assign led = (state == PULSE1) | (state == PULSE2) | (state == PULSE3);
endmodule

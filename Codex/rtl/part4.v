module week5_part4 #(
    parameter [24:0] HALF_SECOND_CYCLES = 25'd25000000
) (
    input CLOCK_50,
    input [1:0] KEY,
    input [2:0] SW,
    output [9:0] LEDR
);
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PULSE = 2'd1;
    localparam [1:0] GAP = 2'd2;

    wire reset_n;
    wire start_press;
    wire half_second_tick;
    reg start_meta;
    reg start_sync;
    reg start_previous;
    reg [2:0] letter_meta;
    reg [2:0] letter_sync;
    reg [3:0] selected_code;
    reg [2:0] selected_length;
    reg [1:0] state;
    reg [24:0] timer;
    reg [3:0] code;
    reg [2:0] remaining;
    reg [1:0] pulse_ticks;

    assign reset_n = KEY[0];
    assign start_press = start_previous & ~start_sync;
    assign half_second_tick = (timer == HALF_SECOND_CYCLES - 25'd1);

    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            start_meta <= 1'b1;
            start_sync <= 1'b1;
            start_previous <= 1'b1;
            letter_meta <= 3'd0;
            letter_sync <= 3'd0;
        end else begin
            start_meta <= KEY[1];
            start_sync <= start_meta;
            start_previous <= start_sync;
            letter_meta <= SW;
            letter_sync <= letter_meta;
        end
    end

    always @(*) begin
        case (letter_sync)
            3'd0: begin selected_code = 4'b0100; selected_length = 3'd2; end
            3'd1: begin selected_code = 4'b1000; selected_length = 3'd4; end
            3'd2: begin selected_code = 4'b1010; selected_length = 3'd4; end
            3'd3: begin selected_code = 4'b1000; selected_length = 3'd3; end
            3'd4: begin selected_code = 4'b0000; selected_length = 3'd1; end
            3'd5: begin selected_code = 4'b0010; selected_length = 3'd4; end
            3'd6: begin selected_code = 4'b1100; selected_length = 3'd3; end
            3'd7: begin selected_code = 4'b0000; selected_length = 3'd4; end
            default: begin selected_code = 4'b0000; selected_length = 3'd1; end
        endcase
    end

    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n)
            timer <= 25'd0;
        else if (state == IDLE || half_second_tick)
            timer <= 25'd0;
        else
            timer <= timer + 25'd1;
    end

    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            code <= 4'b0000;
            remaining <= 3'd0;
            pulse_ticks <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start_press) begin
                        code <= selected_code;
                        remaining <= selected_length;
                        pulse_ticks <= selected_code[3] ? 2'd3 : 2'd1;
                        state <= PULSE;
                    end
                end
                PULSE: begin
                    if (half_second_tick) begin
                        if (pulse_ticks == 2'd1) begin
                            code <= {code[2:0], 1'b0};
                            remaining <= remaining - 3'd1;
                            state <= (remaining == 3'd1) ? IDLE : GAP;
                        end else begin
                            pulse_ticks <= pulse_ticks - 2'd1;
                        end
                    end
                end
                GAP: begin
                    if (half_second_tick) begin
                        pulse_ticks <= code[3] ? 2'd3 : 2'd1;
                        state <= PULSE;
                    end
                end
                default: begin
                    state <= IDLE;
                    code <= 4'b0000;
                    remaining <= 3'd0;
                    pulse_ticks <= 2'd0;
                end
            endcase
        end
    end

    assign LEDR = {9'b000000000, (state == PULSE)};
endmodule

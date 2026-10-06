//==============================================================================
// Module 1: 8-Bit Synchronous Counter (Part 1, Steps 1–5)
// Requirements:
//   - clk: advances counter on rising edge
//   - reset: active-high synchronous reset to 0 (Priority 1)
//   - load: parallel data preload (Priority 2)
//   - enable: counts up when 1, holds state when 0 (Priority 3)
//   - data: 8-bit input value loaded when load = 1
//   - count: 8-bit output (0 to 255, wraps automatically to 0)
//==============================================================================
module counter_8bit (
    input            clk,
    input            reset,
    input            load,
    input            enable,
    input      [7:0] data,
    output reg [7:0] count
);

    always @(posedge clk) begin
        if (reset)
            count <= 8'd0;
        else if (load)
            count <= data;
        else if (enable)
            count <= count + 8'd1;
    end

endmodule


//==============================================================================
// Module 2: 4-Bit Hexadecimal to 7-Segment Decoder (Part 2)
// Requirements:
//   - bin: 4-bit input (0x0 to 0xF)
//   - seg: 7-bit active-low output (0 = ON, 1 = OFF) for DE1-SoC displays
//==============================================================================
module hex_7seg (
    input      [3:0] bin,
    output reg [6:0] seg
);

    always @(*) begin
        case (bin)
            4'h0: seg = 7'b100_0000; // 0
            4'h1: seg = 7'b111_1001; // 1
            4'h2: seg = 7'b010_0100; // 2
            4'h3: seg = 7'b011_0000; // 3
            4'h4: seg = 7'b001_1001; // 4
            4'h5: seg = 7'b001_0010; // 5
            4'h6: seg = 7'b000_0010; // 6
            4'h7: seg = 7'b111_1000; // 7
            4'h8: seg = 7'b000_0000; // 8
            4'h9: seg = 7'b001_0000; // 9
            4'hA: seg = 7'b000_1000; // A
            4'hB: seg = 7'b000_0011; // b (lowercase)
            4'hC: seg = 7'b100_0110; // C
            4'hD: seg = 7'b010_0001; // d (lowercase)
            4'hE: seg = 7'b000_0110; // E
            4'hF: seg = 7'b000_1110; // F
            default: seg = 7'b111_1111; // Blank (prevents latch inference)
        endcase
    end

endmodule


//==============================================================================
// Module 3: Top-Level DE1-SoC System (Parts 3 & 4)
// Requirements:
//   - KEY[0] used as clock input
//   - SW switches used for control inputs (reset, enable, load, data)
//   - HEX0 used to display lower four bits of counter (count[3:0])
//==============================================================================
module top_de1soc (
    input  [0:0] KEY,        // KEY[0] pushbutton on DE1-SoC
    input  [9:0] SW,         // Slider switches SW[9:0]
    output [6:0] HEX0        // Rightmost 7-segment display HEX0
);

    // 8-bit internal bus between the counter and display decoder
    wire [7:0] count_val;

    // KEY[0] rests at 1 and drops to 0 when pressed.
    // Inverting it (~KEY[0]) ensures the counter increments when pressed.
    wire manual_clk = ~KEY[0];

    // Instantiate 8-Bit Counter
    counter_8bit u_counter (
        .clk    (manual_clk),
        .reset  (SW[0]),            // SW[0] = Reset (Active-high)
        .enable (SW[1]),            // SW[1] = Count Enable
        .load   (SW[2]),            // SW[2] = Load Enable
        .data   ({1'b0, SW[9:3]}),  // SW[9:3] provide data bits (padded to 8 bits)
        .count  (count_val)
    );

    // Instantiate 7-Segment Decoder (Lower 4 bits: count[3:0])
    hex_7seg u_decoder (
        .bin (count_val[3:0]),
        .seg (HEX0)
    );

endmodule

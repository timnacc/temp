//==============================================================================
// Module 1: 8-Bit Synchronous Counter (Steps 1 to 5)
//==============================================================================
module counter_8bit (
    input            clk,       // Clock source (driven by KEY0)
    input            reset,     // Active-High Synchronous Reset (Priority 1)
    input            load,      // Active-High Parallel Load  (Priority 2)
    input            enable,    // Active-High Count Enable   (Priority 3)
    input      [7:0] data,      // 8-bit preload data bus
    output reg [7:0] count      // 8-bit counter output (0 to 255)
);

    // Sequential logic triggered on rising clock edge
    always @(posedge clk) begin
        if (reset)
            count <= 8'd0;              // Priority 1: Clear to zero
        else if (load)
            count <= data;              // Priority 2: Preload data value
        else if (enable)
            count <= count + 8'd1;      // Priority 3: Increment by 1
        // Priority 4 (Hold): Implicit when reset=0, load=0, enable=0
    end

endmodule


//==============================================================================
// Module 2: 4-Bit Hexadecimal to 7-Segment Decoder (Part 2)
//==============================================================================
module hex_7seg (
    input      [3:0] bin,       // 4-bit hexadecimal input (0x0 to 0xF)
    output reg [6:0] seg        // 7-segment display lines (Active-Low)
);

    // Combinational logic: evaluates immediately upon any input change
    always @(*) begin
        case (bin)
            4'h0: seg = 7'b100_0000; // Digit 0
            4'h1: seg = 7'b111_1001; // Digit 1
            4'h2: seg = 7'b010_0100; // Digit 2
            4'h3: seg = 7'b011_0000; // Digit 3
            4'h4: seg = 7'b001_1001; // Digit 4
            4'h5: seg = 7'b001_0010; // Digit 5
            4'h6: seg = 7'b000_0010; // Digit 6
            4'h7: seg = 7'b111_1000; // Digit 7
            4'h8: seg = 7'b000_0000; // Digit 8
            4'h9: seg = 7'b001_0000; // Digit 9
            4'hA: seg = 7'b000_1000; // Letter A
            4'hB: seg = 7'b000_0011; // Letter b (lowercase to differ from 8)
            4'hC: seg = 7'b100_0110; // Letter C
            4'hD: seg = 7'b010_0001; // Letter d (lowercase to differ from 0)
            4'hE: seg = 7'b000_0110; // Letter E
            4'hF: seg = 7'b000_1110; // Letter F
            default: seg = 7'b111_1111; // Blank display (prevents latch inference)
        endcase
    end

endmodule


//==============================================================================
// Module 3: Top-Level DE1-SoC Integration Module (Parts 3 & 4)
//==============================================================================
module top_de1soc (
    input  [3:0] KEY,        // Pushbuttons: Active-Low (1 = unpressed, 0 = pressed)
    input  [9:0] SW,         // Slider Switches: 1 = UP, 0 = DOWN
    output [9:0] LEDR,       // Red LEDs: 1 = Lit, 0 = Dark
    output [6:0] HEX0        // Rightmost 7-Segment Display: Active-Low
);

    // Internal 8-bit bus connecting counter output to decoder and LEDs
    wire [7:0] counter_val;

    // CLOCK POLARITY SELECTION:
    // Because KEY[0] is electrically active-low:
    // - Pressing KEY[0] produces a falling edge (1 -> 0).
    // - Releasing KEY[0] produces a rising edge (0 -> 1).
    // Inverting it (~KEY[0]) ensures the counter increments on the button PRESS.
    // (If your lab instructor prefers counting on button RELEASE, use KEY[0] directly.)
    wire manual_clk = ~KEY[0];

    //--------------------------------------------------------------------------
    // 1. Counter Instantiation
    //--------------------------------------------------------------------------
    counter_8bit u_counter (
        .clk    (manual_clk),
        .reset  (SW[0]),             // SW[0] UP = Reset counter to 0
        .enable (SW[1]),             // SW[1] UP = Allow counting
        .load   (SW[2]),             // SW[2] UP = Load data on clock edge
        .data   ({1'b0, SW[9:3]}),   // SW[9:3] provide 7 bits; padded with 1'b0 to 8 bits
        .count  (counter_val)
    );

    //--------------------------------------------------------------------------
    // 2. 7-Segment Decoder Instantiation (Lower 4 bits displayed on HEX0)
    //--------------------------------------------------------------------------
    hex_7seg u_decoder (
        .bin (counter_val[3:0]),     // Lower nibble (0x0 to 0xF)
        .seg (HEX0)                  // Segment lines connected to physical HEX0 pins
    );

    //--------------------------------------------------------------------------
    // 3. Direct Binary LED Verification
    //--------------------------------------------------------------------------
    assign LEDR[7:0] = counter_val;  // Shows full 8-bit binary count on red LEDs
    assign LEDR[9:8] = 2'b00;        // Ground unused LEDs to avoid floating pins

endmodule
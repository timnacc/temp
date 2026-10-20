# Week 6 Explained from Scratch: 3-Tap FIR Filter & What GPT Built

This guide explains **everything** about Week 6 from the ground up—both the core concepts from the lecture and the exact code/files in `verilog/week6/`.

---

## 1. The Big Picture: What Is an FIR Filter?

Imagine you are measuring a sensor (or playing audio), and the numbers jump around wildly from moment to moment. How do you smooth out sudden spikes? **You average the current reading with recent past readings.**

In signal processing:
- Discrete time steps (clock ticks) are numbered `k = 0, 1, 2, ...`
- `x[k]` is the **current input sample** arriving right now.
- `x[k-1]` is the **previous sample** (from 1 clock tick ago).
- `x[k-2]` is the **sample from 2 clock ticks ago**.

Your 3-tap **Finite Impulse Response (FIR)** filter calculates a weighted average of those three samples:

```text
y[k] = a0 * x[k] + a1 * x[k-1] + a2 * x[k-2]
```

Why is it called **3-tap**?
Picture a pipe where the signal flows through registers from left to right. At 3 points along the pipe (`x[k]`, `x[k-1]`, and `x[k-2]`), you "tap" into the pipe to read the value, multiply each by its weight (`a0, a1, a2`), and add them together.

> **What does `z^-1` mean in the lecture slides?**
> In the professor's slides (`lectures/week6/week6_lecture_material.pdf`), each box labeled `z^-1` simply means **"delay by 1 clock cycle"**. In digital hardware, a 1-cycle delay for an 8-bit number is just an **8-bit register (8 D flip-flops)**.

---

## 2. Pre-Work Step 1: Finding Your Filter Weights (`a0, a1, a2`)

The worksheet (`lectures/week6/week6_filter_2026.pdf`) uses your student number (**`042301097`**) to give you unique weights:

1. Take the last two digits: `A0 = 97`
2. Swap those two digits: `A1 = 79`
3. Add them together: `A2 = A0 + A1 = 97 + 79 = 176`
4. Divide each by the total sum (`97 + 79 + 176 = 352`) so the three weights add up to `1.0`:
   - `a0 = 97 / 352 ≈ 0.275568`
   - `a1 = 79 / 352 ≈ 0.224432`
   - `a2 = 176 / 352 = 0.5`

### Why must the weights add up to `<= 1`?
Your input `X` is an **8-bit unsigned integer** (`0` to `255`), and your output `Y` is also an **8-bit unsigned integer** (`0` to `255`).
- Suppose you feed in a steady maximum signal: `x[k] = 255, x[k-1] = 255, x[k-2] = 255`.
- Then `y[k] = (a0 + a1 + a2) * 255`.
- If `a0 + a1 + a2 > 1`, the output would exceed `255` (for example, `260`) and **overflow/wrap around** to `4` in 8-bit binary! In audio, wraparound causes loud, harsh clipping noise.
- If `a0 + a1 + a2 <= 1`, the output never exceeds `255`. Losing a tiny bit of volume (**attenuation**) is completely safe.

---

## 3. Pre-Work Step 2: How Do We Multiply by Decimals in Hardware?

Standard FPGAs don't have floating-point wires—every wire is just `0` or `1`. And building a full hardware multiplier/divider circuit takes a lot of chip area.

Instead, we use a classic digital-design trick: **shifting bits to the right divides by powers of 2 for free!**

### How Right-Shifting Works (`>>`)
In decimal, moving digits right by 1 place divides by 10 (`140 -> 14`).
In binary, moving bits right by 1 place divides by 2 (and drops the remainder):
- `X >> 1` -> `floor(X / 2)   = 0.5 X`
- `X >> 2` -> `floor(X / 4)   = 0.25 X`
- `X >> 3` -> `floor(X / 8)   = 0.125 X`
- `X >> 4` -> `floor(X / 16)  = 0.0625 X`
- `X >> 5` -> `floor(X / 32)  = 0.03125 X`
- `X >> 6` -> `floor(X / 64)  = 0.015625 X`
- `X >> 7` -> `floor(X / 128) = 0.0078125 X`

> **Hardware reality check:** A fixed shift like `X >> 2` uses **zero logic gates and zero flip-flops**! It is literally just routing wires: bit 7 goes to bit 5, bit 6 goes to bit 4, ..., bit 2 goes to bit 0, and the top two wires (`[7:6]`) are tied to `0`.

### Approximating Your Coefficients Using At Most 3 Shifts
The worksheet states you can use **at most 3 shift operations** per constant multiplier (`cm0` and `cm1`):

| Coefficient | Exact Target | Chosen Power-of-2 Sum | Approximated Value | Verilog Shift Expression |
|---|---|---|---|---|
| **`a0` (`cm0`)** | `0.275568` | `1/4 + 1/64 + 1/128 = 35/128` | **`0.2734375`** | `(X >> 3'd2) + (X >> 3'd6) + (X >> 3'd7)` |
| **`a1` (`cm1`)** | `0.224432` | `1/8 + 1/16 + 1/32 = 7/32` | **`0.21875`** | `(X >> 3'd3) + (X >> 3'd4) + (X >> 3'd5)` |
| **`a2` (shifter)** | `0.5` | `1/2` | **`0.5`** | `x_delay2 >> 3'd1` |
| **Total Sum** | **`1.000000`** | `35/128 + 28/128 + 64/128 = 127/128` | **`0.9921875 <= 1`** | Max output for `X = 255` is `67 + 53 + 127 = 247` |

Look at how clean that is:
1. Neither `a0` nor `a1` uses more than 3 shifts.
2. Their sum is `127/128 = 0.9921875`, which is right under `1.0` (only `0.78%` below unity).
3. Even if the input is `255` forever, the maximum possible output is `67 + 53 + 127 = 247`, which safely fits in 8 bits (`0..255`) without ever overflowing!

---

## 4. Walkthrough of the Verilog Files (`verilog/week6/rtl/`)

There are three small, clean synthesizable Verilog files in `rtl/`:

### 1. `cm0.v` — Constant Multiplier for `a0`
```verilog
module cm0 (
    input [7:0] X,
    output [7:0] Z
);
    // 35/128 = 1/4 + 1/64 + 1/128; each shift discards its low bits.
    assign Z = (X >> 3'd2) + (X >> 3'd6) + (X >> 3'd7);
endmodule
```
- **Hardware:** Purely combinational (no clock). Takes the 8-bit wire `X`, creates three shifted wire bundles (`X/4`, `X/64`, `X/128`), and feeds them into two 8-bit adders to produce `Z`.

### 2. `cm1.v` — Constant Multiplier for `a1`
```verilog
module cm1 (
    input [7:0] X,
    output [7:0] Z
);
    // 7/32 = 1/8 + 1/16 + 1/32; no general multiplier is needed.
    assign Z = (X >> 3'd3) + (X >> 3'd4) + (X >> 3'd5);
endmodule
```
- **Hardware:** Purely combinational. Takes an 8-bit input (which will be connected to `x_delay1`, i.e., `x[k-1]`), shifts by 3, 4, and 5 bits, and adds them together.

### 3. `fir_filter.v` — The 3-Tap FIR Filter
![Week 6 FIR structural diagram](diagrams/fir_filter.png)

Let's read `fir_filter.v` piece by piece:

```verilog
module fir_filter (
    input [7:0] X,
    input clk,
    input reset,
    output reg [7:0] Y
);
    reg [7:0] x_delay1; // Holds x[k-1] (8 flip-flops)
    reg [7:0] x_delay2; // Holds x[k-2] (8 flip-flops)
    wire [7:0] tap0;    // Output of cm0: a0 * x[k]
    wire [7:0] tap1;    // Output of cm1: a1 * x[k-1]
    wire [7:0] tap2;    // Output of shifter: a2 * x[k-2]
    wire [9:0] sum;     // 10-bit sum wire
```
Next, it connects the multipliers and adder:
```verilog
    cm0 multiplier0 (.X(X), .Z(tap0));
    cm1 multiplier1 (.X(x_delay1), .Z(tap1));

    assign tap2 = x_delay2 >> 3'd1;
    assign sum = {2'b00, tap0} + {2'b00, tap1} + {2'b00, tap2};
```
Finally, on every rising clock edge (`posedge clk`), it updates the registers:
```verilog
    always @(posedge clk) begin
        if (reset) begin
            x_delay1 <= 8'd0;
            x_delay2 <= 8'd0;
            Y <= 8'd0;
        end else begin
            x_delay1 <= X;
            x_delay2 <= x_delay1;
            Y <= sum[7:0];
        end
    end
endmodule
```

### Let's Trace 4 Clock Ticks by Hand (Just Like the Lecture Slides!)
Suppose we reset the circuit, and then send a single pulse `X = 128`, followed by `0, 0, 0`.
Remember: nonblocking assignments (`<=`) all evaluate their right-hand sides **at the same time** using the values that existed *just before* the clock edge!

| Clock Tick | `X` (current) | `x_delay1` (`x[k-1]`) | `x_delay2` (`x[k-2]`) | `tap0` (`cm0(X)`) | `tap1` (`cm1(x_delay1)`) | `tap2` (`x_delay2 >> 1`) | `Y` after clock edge |
|---|---|---|---|---|---|---|---|
| **Reset** (`reset=1`) | any | `0` | `0` | — | — | — | **`0`** |
| **Tick 0** (`k=0`) | `128` | `0` | `0` | `32+2+1 = 35` | `0` | `0` | **`35`** |
| **Tick 1** (`k=1`) | `0` | `128` | `0` | `0` | `16+8+4 = 28` | `0` | **`28`** |
| **Tick 2** (`k=2`) | `0` | `0` | `128` | `0` | `0` | `64` | **`64`** |
| **Tick 3** (`k=3`) | `0` | `0` | `0` | `0` | `0` | `0` | **`0`** |

Notice how sending a single spike of `128` produces `35`, then `28`, then `64`, and then `0`! Those three numbers (`35/128`, `28/128`, `64/128`) are literally your three filter coefficients (`a0, a1, a2`) coming out one by one. That is why this is called a **Finite Impulse Response (FIR)** filter—when you hit it with a single impulse, its response finishes in a finite number of steps (3 steps).

---

## 5. Lab Work Steps 4 & 5: The Chirp Signal & File-I/O Testbench

How do we test which frequencies our filter lets through and which frequencies it blocks?
Instead of testing one frequency at a time, we feed in a **chirp signal**—a cosine wave that starts at **0 Hz** (very slow oscillation) and smoothly speeds up to **500 Hz** over 2 seconds:
- At `t = 0 s`: frequency `= 0 Hz`
- At `t = 1 s`: frequency `= 250 Hz`
- At `t = 2 s`: frequency `= 500 Hz` (sampled at `1000 samples/second`, so `2000 samples` total).

### Why do we map `[-1, +1]` to `[0, 255]`?
A normal cosine wave goes negative (`-1` to `+1`), but our 8-bit hardware wires are **unsigned** (`0` to `255`).
So `scripts/generate_chirp.py` (and `scripts/generate_chirp.m`) shifts and scales the wave so it oscillates around the midpoint **`127.5` (`128`)**:
- `-1.0 -> 0` (`00000000`)
- ` 0.0 -> 128` (`10000000`)
- `+1.0 -> 255` (`11111111`)

It writes all 2,000 8-bit binary strings into `sim/X.txt`.

### How `tb_chirp.v` Works
In `sim/tb_chirp.v`:
1. `$fopen("X.txt", "r")` opens the input file, and `$fopen("Y.txt", "w")` opens the output file.
2. In a `while` loop, `$fscanf(input_file, "%b", binary_sample)` reads one 8-bit binary line per clock cycle and drives `X`.
3. After each rising clock edge (`@(posedge clk)`), `$fwrite(output_file, "%08b\n", Y)` writes the filter's 8-bit binary output `Y` into `sim/Y.txt`.
4. It also self-checks every single row against an integer math model and prints `PASS`.

---

## 6. Lab Work Step 6: Understanding the Plots & Filter Characteristics

### Plot 1: Full Time-Domain Chirp (`X` vs `Y`)
![Full chirp plot](plots/chirp_full.png)

- **Top plot (Input `X`):** Swings all the way from `0` to `255` from start (`0 s`) to finish (`2 s`).
- **Bottom plot (Output `Y`):**
  - On the left (`0 s` to `0.5 s`, low frequencies), the orange wave is tall—almost the same height as the input (`0` to `247`).
  - Around the vertical dashed line (`t ≈ 0.60 s`, which is `f ≈ 149 Hz`), the wave height drops to about `70.7%` of its starting height (the **`-3 dB` cut-off point**).
  - Around `t ≈ 1.2 s` (`f ≈ 300 Hz`), the output is squeezed the most (adjacent peaks and troughs of the input cancel each other out when averaged).
  - Near the end (`t > 1.5 s`), it rebounds slightly because a 3-tap filter with uneven weights (`a2 = 0.5` is much larger than `a0` and `a1`) cannot completely cancel every high frequency, though it still stays well below the pass-band.

### Plot 2: Zoomed-In Time Segments
![Zoomed chirp detail](plots/chirp_detail.png)

- **Top (5–35 Hz, slow wave):** The orange output (`Y`) tracks the blue input (`X`) closely, just shifted slightly to the right (because the filter averages with delayed samples `x[k-1]` and `x[k-2]`).
- **Middle (142–162 Hz, near cut-off):** You can clearly see the orange peaks are noticeably shorter than the blue peaks.
- **Bottom (438–458 Hz, fast wave):** The blue input jumps wildly every sample, while the orange output is much smaller in swing.

### Plot 3: Frequency Response Curve
![Frequency response](plots/frequency_response.png)

This summarizes the three questions in Step 6 of the worksheet:

1. **a) What type of filter is it?**
   - **Low-pass filter.** Low frequencies pass through with almost full strength (`~0 dB`), while higher frequencies above `~149 Hz` are attenuated.
2. **b) What is the gain in the pass-band (in dB)?**
   - Because our approximated weights add up to `127/128 = 0.9921875` instead of `1.0`:
     `Gain_dB = 10 * log10(P_out / P_in) = 20 * log10(127 / 128) ≈ -0.068 dB`
   - And when measuring the actual quantized 8-bit integer output (which also loses tiny fractions due to integer truncation in the 7 right-shifts), the effective AC pass-band gain is **`-0.143 dB`**—still right next to `0 dB`, just as the worksheet notes!
3. **c) What is the cut-off frequency?**
   - The cut-off frequency is where power drops by half (`-3 dB`, which means amplitude is `1/sqrt(2) ≈ 0.707` of its pass-band value).
   - Both theory and simulation agree this happens at **`f_c ≈ 149 Hz`** (which occurs at time `t = 149 / 250 ≈ 0.596 s` in the chirp).

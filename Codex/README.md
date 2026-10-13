# Week 5 lab

The solutions are in `rtl/`. All `.v` files remain comment-free.

| Part | Add this HDL file to your project | Top-level entity |
|---|---|---|
| I: one-hot | [part1.v](rtl/part1.v) | `week5_part1` |
| I: modified one-hot | [part1_modified.v](rtl/part1_modified.v) | `week5_part1_modified` |
| II: binary FSM | [part2.v](rtl/part2.v) | `week5_part2` |
| III: shift registers | [part3.v](rtl/part3.v) | `week5_part3` |
| IV: Morse encoder | [part4.v](rtl/part4.v) | `week5_part4` |

## Using your usual Pin Planner workflow

1. Create a Quartus project as you did before, using the course's DE1-SoC device (`5CSEMA5F31C6` in the supplied projects).
2. Add only the selected solution file from `rtl/` and set its top-level entity from the table above.
3. Run Analysis & Elaboration to discover the ports. Make pin assignments using your usual method, such as Pin Planner or the course pin file.
4. For Part II, set **State Machine Processing** to **User-Encoded**, as required by the lab. Later change it to One-Hot for the comparison exercise.
5. For Part IV, include [part4.sdc](quartus/part4.sdc) as the timing constraint file; it specifies the 50 MHz clock. Keep the HDL timing parameter at its default value.
6. Compile and program the board. Do not add the `sim/` testbenches to synthesis.

For Parts I–III, SW0 is active-low synchronous reset, SW1 is the input, KEY0 press samples the input, and LEDR9 shows detection. To reset, set SW0 to 0 and press KEY0, then set SW0 back to 1.

For Part IV, SW2–0 selects A–H, KEY1 starts playback, KEY0 resets immediately, and LEDR0 shows Morse pulses. CLOCK_50 supplies the clock.

## What are .qpf and .qsf?

`.qpf` is the Quartus project file you open. `.qsf` stores project settings, including the device, HDL source files, and pin assignments. Quartus manages these files when you use its GUI, so you can continue assigning pins the way you already know. See the [Intel Quartus project guide](https://docs.altera.com/r/docs/683475/19.4/intel-quartus-prime-standard-edition-user-guide-getting-started/intel-quartus-prime-project-contents).

The supplied project files are preserved in `quartus/`. You may open one of them or create your own project using the steps above.

## Folder guide

| Folder | Contents |
|---|---|
| `rtl/` | Five comment-free solution files |
| `quartus/` | Preserved project files, pin settings, and clock constraint |
| `sim/` | Testbenches and simulation scripts; run simulations from this folder |
| `docs/` | [Diagrams](docs/DIAGRAMS.md) and [commented walkthrough](docs/WALKTHROUGH.md) |

All solutions previously passed simulation. Quartus compilation and physical board testing remain to be done in the lab.

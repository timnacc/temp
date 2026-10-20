"""Generate the lab's unsigned, eight-bit linear chirp (standard library only)."""

import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SAMPLE_RATE = 1000
SAMPLE_COUNT = 2000
SWEEP_RATE = 250  # Hz per second; f(1 s) = 250 Hz.


def chirp_samples():
    samples = []
    for index in range(SAMPLE_COUNT):
        time = index / SAMPLE_RATE
        # Integral of f(t) = 250*t gives phase = 2*pi*125*t**2.
        signal = math.cos(math.pi * SWEEP_RATE * time * time)
        mapped = (signal + 1.0) * 127.5
        # Round nonnegative values like MATLAB, rather than Python's ties-to-even.
        samples.append(min(255, max(0, math.floor(mapped + 0.5))))
    return samples


def main():
    output = ROOT / "sim" / "X.txt"
    output.write_text("".join(f"{sample:08b}\n" for sample in chirp_samples()))
    print(f"Wrote {SAMPLE_COUNT} eight-bit samples to {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

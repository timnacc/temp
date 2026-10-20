"""Check actual HDL output, plot the chirp, and measure its AC response."""

import json
import math
import os
from pathlib import Path
import tempfile

os.environ.setdefault("MPLCONFIGDIR", str(Path(tempfile.gettempdir()) / "week6-matplotlib"))

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from generate_chirp import SAMPLE_COUNT, SAMPLE_RATE, SWEEP_RATE, chirp_samples


ROOT = Path(__file__).resolve().parents[1]
PLOTS = ROOT / "docs" / "plots"
EXACT = np.array([97 / 352, 79 / 352, 0.5])
APPROX = np.array([35 / 128, 7 / 32, 0.5])


def read_binary(path):
    lines = path.read_text().splitlines()
    if len(lines) != SAMPLE_COUNT:
        raise ValueError(f"{path.name}: expected {SAMPLE_COUNT} rows, got {len(lines)}")
    for index, line in enumerate(lines, start=1):
        if len(line) != 8 or set(line) - {"0", "1"}:
            raise ValueError(f"{path.name}: row {index} is not exactly eight binary digits")
    return np.array([int(line, 2) for line in lines], dtype=np.int64)


def integer_reference(x):
    previous1 = np.concatenate(([0], x[:-1]))
    previous2 = np.concatenate(([0, 0], x[:-2]))
    return (x // 4 + x // 64 + x // 128
            + previous1 // 8 + previous1 // 16 + previous1 // 32 + previous2 // 2)


def magnitude(frequency, coefficients):
    omega = 2 * np.pi * np.asarray(frequency) / SAMPLE_RATE
    response = sum(coefficient * np.exp(-1j * omega * tap)
                   for tap, coefficient in enumerate(coefficients))
    return np.abs(response)


def cutoff(coefficients):
    target = sum(coefficients) / math.sqrt(2)
    low, high = 0.0, SAMPLE_RATE / 2
    for _ in range(60):
        middle = (low + high) / 2
        if magnitude(middle, coefficients) > target:
            low = middle
        else:
            high = middle
    return (low + high) / 2


def chirp_response(x, y, time):
    # Fit cosine, sine and DC in overlapping 96 ms windows. The sine term
    # permits phase delay; the constant prevents the 127.5-code bias becoming gain.
    phase = np.pi * SWEEP_RATE * time ** 2
    window_size = 96
    half_window = window_size // 2
    weights = np.sqrt(np.hanning(window_size))
    frequencies, gains = [], []
    for center in range(half_window, len(x) - half_window, 8):
        region = slice(center - half_window, center + half_window)
        basis = np.column_stack((np.cos(phase[region]), np.sin(phase[region]),
                                 np.ones(window_size)))
        weighted_basis = basis * weights[:, None]
        input_fit = np.linalg.lstsq(weighted_basis, x[region] * weights, rcond=None)[0]
        output_fit = np.linalg.lstsq(weighted_basis, y[region] * weights, rcond=None)[0]
        gain = np.hypot(*output_fit[:2]) / np.hypot(*input_fit[:2])
        frequencies.append(SWEEP_RATE * time[center])
        gains.append(gain)
    return np.array(frequencies), np.array(gains)


def save_plot(figure, name):
    figure.savefig(PLOTS / f"{name}.png", dpi=160)
    plt.close(figure)


def main():
    x = read_binary(ROOT / "sim" / "X.txt")
    y = read_binary(ROOT / "sim" / "Y.txt")
    if not np.array_equal(x, chirp_samples()):
        raise ValueError("X.txt differs from the specified quantized chirp; regenerate it")
    reference = integer_reference(x)
    if not np.array_equal(y, reference):
        index = int(np.flatnonzero(y != reference)[0])
        raise ValueError(f"HDL output mismatch at row {index + 1}: {y[index]} != {reference[index]}")

    PLOTS.mkdir(parents=True, exist_ok=True)
    time = np.arange(len(x)) / SAMPLE_RATE
    frequencies = np.linspace(0, SAMPLE_RATE / 2, 5001)
    approximate_magnitude = magnitude(frequencies, APPROX)
    dc_gain = float(sum(APPROX))
    cutoff_hz = cutoff(APPROX)
    measured_f, measured_gain = chirp_response(x, y, time)
    # Fit a three-tap linear approximation plus DC bias to actual file data.
    # Integer truncation is nonlinear, so this is an empirical fit, not an exact H(z).
    regression = np.column_stack((x[2:], x[1:-1], x[:-2], np.ones(len(x) - 2)))
    fitted = np.linalg.lstsq(regression, y[2:], rcond=None)[0]
    fitted_gain = float(sum(fitted[:3]))
    fitted_rms_error = float(np.sqrt(np.mean((regression @ fitted - y[2:]) ** 2)))
    target = fitted_gain / math.sqrt(2)
    crossing = int(np.flatnonzero(measured_gain <= target)[0])
    measured_cutoff = float(np.interp(target,
        measured_gain[crossing - 1:crossing + 1][::-1],
        measured_f[crossing - 1:crossing + 1][::-1]))
    linear_output = np.convolve(x, APPROX)[:len(x)]
    truncation_error = y - linear_output

    metrics = {
        "student_number": "042301097",
        "sample_rate_hz": SAMPLE_RATE,
        "sample_count": len(x),
        "last_sample_time_s": float(time[-1]),
        "last_instantaneous_frequency_hz": float(SWEEP_RATE * time[-1]),
        "exact_coefficients": EXACT.tolist(),
        "approximate_coefficients": APPROX.tolist(),
        "filter_type": "low-pass, with a shallow stop-band and high-frequency rebound",
        "coefficient_dc_gain": dc_gain,
        "coefficient_dc_gain_db": float(20 * np.log10(dc_gain)),
        "coefficient_cutoff_hz": cutoff_hz,
        "cutoff_relative_db": float(20 * np.log10(1 / math.sqrt(2))),
        "exact_coefficient_cutoff_hz": cutoff(EXACT),
        "fitted_coefficients": fitted[:3].tolist(),
        "fitted_dc_bias_codes": float(fitted[3]),
        "fitted_passband_gain_db": float(20 * np.log10(fitted_gain)),
        "fitted_cutoff_hz": cutoff(fitted[:3]),
        "fitted_rms_error_codes": fitted_rms_error,
        "chirp_cutoff_estimate_hz": measured_cutoff,
        "response_minimum_frequency_hz": float(frequencies[np.argmin(approximate_magnitude)]),
        "response_minimum_db": float(20 * np.log10(min(approximate_magnitude))),
        "nyquist_gain_db": float(20 * np.log10(approximate_magnitude[-1])),
        "input_range": [int(min(x)), int(max(x))],
        "output_range": [int(min(y)), int(max(y))],
        "hdl_reference_max_error_codes": int(max(abs(y - reference))),
        "mean_truncation_error_codes": float(np.mean(truncation_error[2:])),
        "worst_truncation_error_codes": float(max(abs(truncation_error))),
        "constant_255_output": 247,
        "verification": "Icarus Verilog: 256 inputs per multiplier, 4634 FIR cycles, 2000 chirp rows; Python: every row matches integer arithmetic",
    }
    (ROOT / "docs" / "results.json").write_text(json.dumps(metrics, indent=2) + "\n")

    plt.rcParams.update({"font.size": 10, "axes.grid": True, "grid.alpha": 0.25})
    figure, axes = plt.subplots(2, 1, figsize=(10, 6), sharex=True, layout="constrained")
    axes[0].plot(time, x, linewidth=0.65, color="#54718c")
    axes[0].set(title="Input X: 8-bit linear chirp, 1 kHz sample rate", ylabel="Input (codes)", ylim=(-5, 260))
    axes[1].plot(time, y, linewidth=0.65, color="#cc6534")
    axes[1].set(title="Simulated output Y: attenuation grows, then partly recovers",
                xlabel="Time (s); instantaneous input frequency = 250 t Hz", ylabel="Output (codes)", ylim=(-5, 260))
    for axis in axes:
        axis.axvline(cutoff_hz / SWEEP_RATE, linestyle="--", color="#333333", linewidth=1)
    save_plot(figure, "chirp_full")

    figure, axes = plt.subplots(3, 1, figsize=(10, 7), layout="constrained")
    for axis, start, end in zip(axes, [0.02, 0.57, 1.75], [0.14, 0.65, 1.83]):
        region = (time >= start) & (time < end)
        axis.plot(time[region], x[region], ".-", markersize=2, linewidth=1, label="X (input)")
        axis.plot(time[region], y[region], ".-", markersize=2, linewidth=1, label="Y (HDL output)")
        axis.set(ylabel="Unsigned codes", ylim=(-5, 260),
                 title=f"{SWEEP_RATE * start:.0f}-{SWEEP_RATE * end:.0f} Hz chirp segment")
    axes[0].legend(loc="upper right")
    axes[-1].set_xlabel("Time (s); matching file rows, registered output sampled after the edge")
    save_plot(figure, "chirp_detail")

    figure, axis = plt.subplots(figsize=(10, 4.8), layout="constrained")
    axis.plot(frequencies, 20 * np.log10(magnitude(frequencies, EXACT)),
              linestyle="--", color="#80939d", label="Original coefficients")
    axis.plot(frequencies, 20 * np.log10(approximate_magnitude),
              color="#286995", label="Shift/add coefficients (linear model)")
    axis.plot(measured_f, 20 * np.log10(measured_gain), color="#cc6534", linewidth=1,
              label="Actual HDL chirp (local AC amplitude fit)")
    axis.axhline(20 * np.log10(dc_gain / math.sqrt(2)), linestyle=":", color="#333333")
    axis.axvline(cutoff_hz, linestyle=":", color="#333333",
                 label=f"Half-power cut-off: {cutoff_hz:.2f} Hz")
    axis.set(title="Three-tap FIR: low-pass shape with high-frequency rebound",
             xlabel="Frequency (Hz)", ylabel="AC amplitude gain (dB)", xlim=(0, 500), ylim=(-17, 1))
    axis.legend(loc="lower left", fontsize=9)
    save_plot(figure, "frequency_response")

    print("PASS: all 2000 X/Y rows checked against chirp and integer FIR reference")
    print(f"Coefficient pass-band gain: {20 * np.log10(dc_gain):.6f} dB")
    print(f"Half-power cut-off: {cutoff_hz:.6f} Hz")
    print(f"Chirp fitted pass-band gain: {20 * np.log10(fitted_gain):.6f} dB")
    print(f"Chirp cut-off estimate: {measured_cutoff:.6f} Hz")


if __name__ == "__main__":
    main()

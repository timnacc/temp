"""Run from this folder with Icarus Verilog (iverilog and vvp) on PATH."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
build = root / "sim_build"
build.mkdir(exist_ok=True)
tests = {
    "sequence": ["part1", "part1_modified", "part2", "part3", "part3_single"],
    "morse": ["part4"],
}
for name, modules in tests.items():
    output = build / (name + ".vvp")
    sources = [str(root / "rtl" / (module + ".v")) for module in modules]
    sources.append(str(root / "tb" / ("tb_" + name + ".v")))
    subprocess.run(["iverilog", "-g2001", "-s", "tb_" + name, "-o", str(output), *sources], check=True)
    result = subprocess.run(["vvp", str(output)], capture_output=True, text=True, check=True)
    print(result.stdout, end="")
    if "FAIL" in result.stdout or "PASS:" not in result.stdout:
        raise SystemExit("Simulation failed: " + name)
print("All simulations passed.")

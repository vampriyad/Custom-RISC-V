#!/usr/bin/env python3

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
OUT = os.path.join(ROOT, "benchmarks", "results.json")

CORES = {
    "single": ["rtl/core/core_single.sv", "rtl/soc/soc_single.sv"],
    "multi":  ["rtl/core/core_multi.sv",  "rtl/soc/soc_multi.sv"],
    "pipe":   ["rtl/core/core_pipe.sv",   "rtl/soc/soc_pipe.sv"],
}

SHARED_RTL = [
    "rtl/core/alu.sv", "rtl/core/regfile.sv", "rtl/core/imm_gen.sv",
    "rtl/core/decoder.sv",
    "rtl/mem/imem.sv", "rtl/mem/dmem.sv",
    "rtl/periph/uart_tx.sv", "rtl/periph/uart_rx.sv", "rtl/periph/uart.sv",
    "rtl/periph/timer.sv", "rtl/custom/dotp.sv",
]

BENCHES = ["bench_dot", "bench_mix"]
TESTS = ["test_basic", "test_mem", "test_hello", "test_timer", "test_dot", "test_hazard"]

BENCH_RE = re.compile(r"BENCH (\S+) (0x[0-9a-fA-F]+)")


def sh(cmd, timeout=600):
    return subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, timeout=timeout)


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    for bench in BENCHES:
        r = sh(f"python3 tools/asm.py programs/asm/{bench}.s -o build/{bench}")
        if r.returncode != 0:
            print(f"assemble failed for {bench}: {r.stderr}")
            sys.exit(1)

    results = {}
    for core, rtl in CORES.items():
        vvp = os.path.join(BUILD, f"tb_soc_{core}.vvp")
        srcs = f"testbench/tb_soc_{core}.sv " + " ".join(rtl + SHARED_RTL)
        r = sh(f"iverilog -g2012 -I rtl/core -o {vvp} {srcs}")
        if r.returncode != 0:
            print(f"compile failed for {core}:\n{r.stderr[:1500]}")
            sys.exit(1)

        results[core] = {}
        for bench in BENCHES:
            out = sh(
                f"vvp {vvp} +HEX=build/{bench}_prog.hex +DATA=build/{bench}_data.hex +TIMEOUT=8000000"
            ).stdout
            entries = {}
            for name, val in BENCH_RE.findall(out):
                entries[name] = int(val, 16)
            m = re.search(r"EXIT code=\d+ cycles=(\d+) instrs=(\d+)", out)
            entries["total_cycles"] = int(m.group(1)) if m else None
            entries["total_instrs"] = int(m.group(2)) if m else None
            ok = f"=== tb_soc_{core} PASSED ===" in out
            entries["selfcheck_passed"] = ok
            results[core][bench] = entries
            print(f"{core:6s} {bench:10s} {entries}")

    print("\n[tests]")
    for core, rtl in CORES.items():
        vvp = os.path.join(BUILD, f"tb_soc_{core}.vvp")
        results[core]["tests"] = {}
        for prog in TESTS:
            sh(f"python3 tools/asm.py programs/asm/{prog}.s -o build/{prog}")
            out = sh(
                f"vvp {vvp} +HEX=build/{prog}_prog.hex +DATA=build/{prog}_data.hex +TIMEOUT=8000000"
            ).stdout
            m = re.search(r"EXIT code=\d+ cycles=(\d+) instrs=(\d+)", out)
            ok = f"=== tb_soc_{core} PASSED ===" in out
            results[core]["tests"][prog] = {
                "cycles": int(m.group(1)) if m else None,
                "instrs": int(m.group(2)) if m else None,
                "passed": ok,
            }
            print(f"{core:6s} {prog:12s} {results[core]['tests'][prog]}")

    with open(OUT, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nwrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

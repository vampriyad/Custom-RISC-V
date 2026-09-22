#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")

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

UNIT_TB = {
    "tb_and_gate": ["rtl/basic/and_gate.sv"],
    "tb_mux":      ["rtl/basic/mux.sv"],
    "tb_register": ["rtl/basic/register.sv"],
    "tb_counter":  ["rtl/basic/counter.sv"],
    "tb_alu":      ["rtl/core/alu.sv"],
    "tb_regfile":  ["rtl/core/regfile.sv"],
    "tb_imm_gen":  ["rtl/core/imm_gen.sv"],
    "tb_decoder":  ["rtl/core/decoder.sv"],
    "tb_uart":     ["rtl/periph/uart_tx.sv", "rtl/periph/uart_rx.sv", "rtl/periph/uart.sv"],
    "tb_timer":    ["rtl/periph/timer.sv"],
    "tb_dotp":     ["rtl/custom/dotp.sv"],
}

PROGRAMS = [
    "test_basic", "test_mem", "test_hello", "test_timer", "test_dot",
    "test_hazard",
]


def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, **kw)


def compile_tb(tb, extra_rtl):
    out = os.path.join(BUILD, tb + ".vvp")
    srcs = [f"testbench/{tb}.sv"] + extra_rtl
    cmd = f"iverilog -g2012 -I rtl/core -o {out} " + " ".join(srcs)
    r = sh(cmd)
    if r.returncode != 0:
        print(f"  COMPILE FAIL {tb}:\n{r.stderr[:2000]}")
        return None
    return out


def run_vvp(vvp, args="", timeout=300):
    r = sh(f"vvp {vvp} {args}", timeout=timeout)
    return r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true", help="unit testbenches only")
    args = ap.parse_args()

    os.makedirs(BUILD, exist_ok=True)
    results = []
    print("== unit testbenches ==")
    for tb, rtl in UNIT_TB.items():
        vvp = compile_tb(tb, rtl)
        if vvp is None:
            results.append((tb, False, "compile error"))
            continue
        out = run_vvp(vvp)
        ok = f"=== {tb} PASSED" in out
        detail = [ln for ln in out.splitlines() if "PASSED" in ln or "FAILED" in ln]
        results.append((tb, ok, detail[-1] if detail else "no verdict"))
        print(f"  {tb:12s} {'PASS' if ok else 'FAIL'}")

    if args.quick:
        return summarize(results)

    print("== programs on all cores ==")
    for prog in PROGRAMS:
        r = sh(f"python3 tools/asm.py programs/asm/{prog}.s -o build/{prog} --list build/{prog}.lst")
        if r.returncode != 0:
            print(f"  ASSEMBLE FAIL {prog}: {r.stderr}")
            results.append((f"asm:{prog}", False, "assemble error"))
            break

    for core, rtl in CORES.items():
        vvp = compile_tb(f"tb_soc_{core}", rtl + SHARED_RTL)
        if vvp is None:
            for prog in PROGRAMS:
                results.append((f"{prog}@{core}", False, "compile error"))
            continue
        for prog in PROGRAMS:
            out = run_vvp(
                vvp,
                f"+HEX=build/{prog}_prog.hex +DATA=build/{prog}_data.hex",
                timeout=300,
            )
            ok = f"=== tb_soc_{core} PASSED ===" in out
            exit_line = [ln for ln in out.splitlines() if "EXIT code" in ln or "TIMEOUT" in ln]
            results.append((f"{prog}@{core}", ok, exit_line[-1] if exit_line else "no verdict"))
            print(f"  {prog:12s} {core:6s} {'PASS' if ok else 'FAIL'}")

    return summarize(results)


def summarize(results):
    n_fail = sum(1 for _, ok, _ in results if not ok)
    print()
    print("=" * 60)
    for name, ok, detail in results:
        if not ok:
            print(f"  FAILED: {name:24s} {detail}")
    print(f"  {len(results) - n_fail}/{len(results)} passed")
    print("=" * 60)
    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(main())

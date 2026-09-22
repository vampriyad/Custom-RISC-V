#!/usr/bin/env python3

import argparse
import os
import re
import sys

DEFAULT_SIGNALS = [
    ("clk",                  "clk"),
    ("rst_n",                "rst_n"),
    ("dbg_pc",               "pc"),
    ("dbg_instr",            "instr"),
    ("u_core.rf_we",         "rf_we"),
    ("u_core.wb_we",         "wb_we"),
    ("u_core.rd",            "rd"),
    ("u_core.wb_rd",         "wb_rd"),
    ("u_core.rf_wdata",      "wb_data"),
    ("u_core.wb_data",       "wb_data"),
    ("dmem_we",              "dmem_we"),
    ("dmem_addr",            "dmem_addr"),
    ("dmem_wdata",           "dmem_wdata"),
]


def parse_vcd(path, want):
    ids = {}
    values = {}
    scopes = []
    t = 0
    times = set()
    id2name = {}
    with open(path) as f:
        in_defs = True
        for line in f:
            line = line.strip()
            if line.startswith("$scope"):
                scopes.append(line.split()[2])
            elif line.startswith("$upscope"):
                if scopes:
                    scopes.pop()
            elif line.startswith("$var"):
                parts = line.split()
                vid, name = parts[3], parts[4]
                full = ".".join(scopes + [name])
                for suffix, label in want:
                    if full.endswith(suffix):
                        ids[vid] = label
                        id2name[label] = vid
                        values[label] = []
            elif line.startswith("$enddefinitions"):
                in_defs = False
            elif not in_defs:
                if line.startswith("#"):
                    t = int(line[1:])
                    times.add(t)
                elif line and line[0] in "01xzbXZB":
                    vid = line[1:]
                    if vid in ids:
                        values[ids[vid]].append((t, line[0]))
                elif line.startswith("b"):
                    val, vid = line[1:].split()
                    if vid in ids:
                        values[ids[vid]].append((t, val))
    return sorted(times), values


def val_at(series, t):
    cur = "x"
    for tt, v in series:
        if tt <= t:
            cur = v
        else:
            break
    return cur


def to_hex(v):
    if not v or any(c in v.lower() for c in "xz"):
        return "x"
    try:
        return f"{int(v, 2):X}"
    except ValueError:
        return "?"


def render(times, values, labels, order, out_path, tmax, width=1100):
    row_h = 34
    ml, mr, mt = 150, 20, 40
    n = len(order)
    height = mt + n * row_h + 20
    pw = width - ml - mr

    vis = [t for t in times if t <= tmax]
    if len(vis) > 220:
        step = len(vis) // 220
        keep = set(vis[::step]) | {vis[-1], 0}
        vis = [t for t in vis if t in keep]

    def x_of(t):
        return ml + pw * (t / tmax if tmax else 0)

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'font-family="Consolas, Menlo, monospace">',
        f'<rect width="{width}" height="{height}" fill="white"/>',
        f'<text x="{ml}" y="24" font-size="14" font-weight="bold" '
        f'font-family="Segoe UI, Arial">Simulation waveform (time in ns)</text>',
    ]

    for i in range(9):
        t = tmax * i // 8
        x = x_of(t)
        out.append(f'<line x1="{x:.1f}" y1="{mt-6}" x2="{x:.1f}" y2="{height-14}" '
                   f'stroke="#eee"/>')
        out.append(f'<text x="{x:.1f}" y="{height-4}" font-size="9" fill="#777" '
                   f'text-anchor="middle">{t}</text>')

    for i, label in enumerate(order):
        y = mt + i * row_h
        out.append(f'<text x="{ml-8}" y="{y+row_h/2+4}" font-size="11" text-anchor="end" '
                   f'fill="#222">{label}</text>')
        series = values.get(label, [])
        width_bits = 1
        is_bus = any(len(v) > 1 for _, v in series)
        mid = y + row_h / 2
        h = row_h * 0.55

        if not is_bus:
            prev = "x"
            for j in range(len(vis)):
                t = vis[j]
                v = val_at(series, t)
                x0 = x_of(t)
                x1 = x_of(vis[j + 1]) if j + 1 < len(vis) else x_of(tmax)
                if v == "1":
                    out.append(f'<rect x="{x0:.1f}" y="{mid-h/2:.1f}" width="{x1-x0:.1f}" '
                               f'height="{h:.1f}" fill="#2F9E44"/>')
                elif v == "0":
                    out.append(f'<rect x="{x0:.1f}" y="{mid+h/2-3:.1f}" width="{x1-x0:.1f}" '
                               f'height="3" fill="#333"/>')
                    out.append(f'<line x1="{x0:.1f}" y1="{mid+h/2-3:.1f}" x2="{x0:.1f}" '
                               f'y2="{mid+h/2:.1f}" stroke="#333"/>')
                else:
                    out.append(f'<rect x="{x0:.1f}" y="{mid-h/2:.1f}" width="{x1-x0:.1f}" '
                               f'height="{h:.1f}" fill="#bbb"/>')
                if v != prev and prev != "x":
                    out.append(f'<line x1="{x0:.1f}" y1="{mid-h/2:.1f}" x2="{x0:.1f}" '
                               f'y2="{mid+h/2:.1f}" stroke="#111"/>')
                prev = v
        else:
            prev_hex = None
            for j in range(len(vis)):
                t = vis[j]
                v = to_hex(val_at(series, t))
                x0 = x_of(t)
                x1 = x_of(vis[j + 1]) if j + 1 < len(vis) else x_of(tmax)
                out.append(f'<polygon points="{x0:.1f},{mid} {x0+4:.1f},{mid-h/2:.1f} '
                           f'{x1-4:.1f},{mid-h/2:.1f} {x1:.1f},{mid} {x1-4:.1f},{mid+h/2:.1f} '
                           f'{x0+4:.1f},{mid+h/2:.1f}" fill="#D0EBFF" stroke="#1971C2"/>')
                if v != prev_hex and x1 - x0 > 18:
                    out.append(f'<text x="{(x0+x1)/2:.1f}" y="{mid+4:.1f}" font-size="10" '
                               f'text-anchor="middle" fill="#1971C2">{v}</text>')
                prev_hex = v

    out.append("</svg>")
    with open(out_path, "w") as f:
        f.write("\n".join(out))
    print(f"wrote {out_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd")
    ap.add_argument("out")
    ap.add_argument("--cycles", type=int, default=36, help="nanoseconds to show (10ns/cycle)")
    ap.add_argument("--scale", type=int, default=40, help="pixels per cycle (informational; --width sets the real width)")
    ap.add_argument("--width", type=int, default=1100, help="image width in pixels")
    args = ap.parse_args()

    times, values = parse_vcd(args.vcd, DEFAULT_SIGNALS)
    order = [label for _, label in DEFAULT_SIGNALS if label in values]
    missing = [label for _, label in DEFAULT_SIGNALS if label not in values]
    if missing:
        print(f"warning: not found in vcd: {missing}", file=sys.stderr)
    render(times, values, values, order, args.out, args.cycles * 10, width=args.width)


if __name__ == "__main__":
    main()

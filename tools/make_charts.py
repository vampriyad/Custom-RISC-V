#!/usr/bin/env python3

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIGS = os.path.join(ROOT, "benchmarks", "figures")

PALETTE = {"single": "#4C6EF5", "multi": "#F59F00", "pipe": "#2F9E44"}
CORES = ["single", "multi", "pipe"]


def svg_bars(path, title, series, names, colors, ylabel, width=760, height=380):
    ml, mr, mt, mb = 60, 20, 44, 70
    pw, ph = width - ml - mr, height - mt - mb
    vmax = max(max(vs) for _, vs in series) or 1
    n_groups = len(names)
    n_bars = len(series)
    gw = pw / n_groups
    bw = gw * 0.72 / n_bars

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'font-family="Segoe UI, Helvetica, Arial, sans-serif">',
        f'<rect width="{width}" height="{height}" fill="white"/>',
        f'<text x="{width/2}" y="24" text-anchor="middle" font-size="15" '
        f'font-weight="bold">{title}</text>',
    ]
    for i in range(5):
        y = mt + ph * i / 4
        val = int(vmax * (4 - i) / 4)
        out.append(f'<line x1="{ml}" y1="{y}" x2="{ml+pw}" y2="{y}" stroke="#ddd"/>')
        out.append(f'<text x="{ml-6}" y="{y+4}" text-anchor="end" font-size="11" '
                   f'fill="#555">{val}</text>')
    out.append(f'<text x="16" y="{mt+ph/2}" font-size="12" fill="#333" '
               f'transform="rotate(-90 16 {mt+ph/2})" text-anchor="middle">{ylabel}</text>')

    for gi, name in enumerate(names):
        gx = ml + gi * gw
        for si, (slabel, vs) in enumerate(series):
            v = vs[gi]
            bh = ph * v / vmax
            x = gx + gw * 0.14 + si * bw
            y = mt + ph - bh
            out.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bw*0.9:.1f}" '
                       f'height="{bh:.1f}" fill="{colors[si]}"/>')
            out.append(f'<text x="{x + bw*0.45:.1f}" y="{y-4:.1f}" text-anchor="middle" '
                       f'font-size="10" fill="#333">{v}</text>')
        out.append(f'<text x="{gx+gw/2:.1f}" y="{mt+ph+16}" text-anchor="middle" '
                   f'font-size="12" fill="#222">{name}</text>')

    lx = ml
    ly = height - 28
    for si, (slabel, _) in enumerate(series):
        out.append(f'<rect x="{lx}" y="{ly-11}" width="12" height="12" fill="{colors[si]}"/>')
        out.append(f'<text x="{lx+16}" y="{ly}" font-size="12" fill="#222">{slabel}</text>')
        lx += 22 + 9 * len(slabel)
    out.append("</svg>")
    with open(path, "w") as f:
        f.write("\n".join(out))
    print(f"  wrote {os.path.relpath(path, ROOT)}")


def main():
    os.makedirs(FIGS, exist_ok=True)
    bench = json.load(open(os.path.join(ROOT, "benchmarks", "results.json")))
    synth = json.load(open(os.path.join(ROOT, "synthesis", "reports", "summary.json")))

    names = ["sw_rolled", "sw_unrolled", "hw_stream", "hw_cached"]
    series = [(f"{c} core", [bench[c]["bench_dot"].get(n, 0) for n in names]) for c in CORES]
    svg_bars(os.path.join(FIGS, "fig_dot_cycles.svg"),
             "64 x 4-lane dot products -- cycles (lower is better)",
             series, names, [PALETTE[c] for c in CORES], "cycles")

    names = ["mac512", "sum512", "copy256", "sort32"]
    series = [(f"{c} core", [bench[c]["bench_mix"].get(n, 0) for n in names]) for c in CORES]
    svg_bars(os.path.join(FIGS, "fig_mix_cycles.svg"),
             "Mixed workload -- cycles (lower is better)",
             series, names, [PALETTE[c] for c in CORES], "cycles")

    names = ["core_single", "core_multi", "core_pipe", "dotp", "uart", "timer"]
    series = [("LUTs", [synth[n]["luts"] for n in names]),
              ("FFs", [synth[n]["ffs"] for n in names])]
    svg_bars(os.path.join(FIGS, "fig_resources.svg"),
             "Post-synthesis resources (xc7 mapping)",
             series, names, ["#4C6EF5", "#E8590C"], "cells")

    D = {c: synth[f"soc_{c}"]["ltp_depth"] for c in CORES}
    names = ["mac512", "sum512", "copy256", "sort32"]
    series = []
    for c in CORES:
        vs = [bench[c]["bench_mix"].get(n, 0) * D[c] for n in names]
        series.append((f"{c} (cycles x depth)", vs))
    svg_bars(os.path.join(FIGS, "fig_time_model.svg"),
             "Estimated time = cycles x logic depth (arb. units)",
             series, names, [PALETTE[c] for c in CORES], "cycles x depth")

    d = bench["single"]["bench_dot"]
    names = ["vs sw_rolled", "vs sw_unrolled", "vs hw_stream"]
    series = [("speedup x", [round(d["sw_rolled"] / d["hw_cached"], 1),
                             round(d["sw_unrolled"] / d["hw_cached"], 1),
                             round(d["hw_stream"] / d["hw_cached"], 1)])]
    svg_bars(os.path.join(FIGS, "fig_dot_speedup.svg"),
             "CDOT cached throughput vs other dot-product paths (single-cycle core)",
             series, names, ["#2F9E44"], "speedup")


if __name__ == "__main__":
    main()

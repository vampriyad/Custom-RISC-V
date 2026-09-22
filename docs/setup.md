# Setup guide (Windows)

Everything in this project runs on plain Windows 10/11 from PowerShell or
cmd. No FPGA board, no WSL and no Linux needed. Three installs and you can
run every test, benchmark and synthesis flow.

## 1. Python 3

1. Go to <https://www.python.org/downloads/> and run the latest Python 3
   installer.
2. On the first page, tick **"Add python.exe to PATH"**.
3. Finish the install.

Check it:

```powershell
python --version
```

(If that prints the Microsoft Store stub instead of a version, either run
`py --version` and use `py` in place of `python`, or turn off
"App execution aliases" for python.exe in Windows settings.)

The scripts in `tools/` only use the Python standard library.

## 2. The HDL tools (Icarus Verilog + Yosys + GTKWave)

The easiest single install is **OSS CAD Suite**, a bundle of open-source EDA
tools with ready-to-run Windows builds.

1. Go to <https://github.com/YosysHQ/oss-cad-suite-build/releases> and
   download `oss-cad-suite-windows-x64-<date>.zip` from the newest release.
2. Unzip it somewhere without spaces in the path, for example
   `C:\eda\oss-cad-suite`.
3. Add its `bin` directory to your **user** PATH:

   ```powershell
   [Environment]::SetEnvironmentVariable("Path",
       $env:Path + ";C:\eda\oss-cad-suite\bin", "User")
   ```

4. Open a **new** terminal and check:

   ```powershell
   iverilog -V
   yosys -V
   gtkwave --version
   ```

### Alternative: install the tools separately

* Icarus Verilog for Windows (Bleyer release):
  <https://bleyer.org/icarus/> -- run the installer, it adds itself to PATH.
* Yosys: the OSS CAD Suite build above, or
  <https://github.com/YosysHQ/oss-cad-suite-build>.
* GTKWave (optional, for looking at raw `.vcd` dumps):
  <https://sourceforge.net/projects/gtkwave/>.

Only `iverilog`, `vvp` and `yosys` are required by the Makefile/scripts.
GTKWave is optional because the repo already includes rendered waveforms and
`tools/vcd2svg.py` can draw any dump without it.

## 3. The project

Get the repository (download the ZIP from GitHub and unpack it, or
`git clone`). From its folder in PowerShell:

```powershell
python tools/run_tests.py     # full 29-test regression
python tools/run_bench.py     # benchmarks -> benchmarks/results.json
python tools/run_synth.py     # synthesis -> synthesis/reports/summary.json
python tools/make_charts.py   # redraw figures
```

That is the whole toolchain. `run_tests.py` should end with
`ALL TESTS PASSED (29/29)`.

### Without make

If you do not have `make` (it is not standard on Windows), the scripts above
are all you need; the `Makefile` is only sugar for Linux/CI. To compile and
run one program by hand:

```powershell
python tools/asm.py programs/asm/hello.s -o build/hello --list build/hello.lst
iverilog -g2012 -o build/tb_soc_single.vvp rtl/basic/*.sv rtl/core/*.sv `
    rtl/mem/*.sv rtl/periph/*.sv rtl/custom/*.sv rtl/soc/soc_single.sv `
    testbench/tb_soc_single.sv
vvp build/tb_soc_single.vvp +HEX=build/hello_prog.hex +DATA=build/hello_data.hex
```

(One wrinkle if you use Icarus: it may print
`sorry: constant selects in always_* processes are not currently supported`
for two ALU lines. It is a cosmetic warning from Icarus's elaborator, not a
design problem; the compiled simulation is correct and Yosys is unaffected.)

## 4. Looking at waveforms

The regression does not dump waves (they slow everything down). To look at
signals for one run:

```powershell
vvp build/tb_soc_single.vvp +HEX=build/hello_prog.hex +DATA=build/hello_data.hex +DUMP
```

This writes `build/dump.vcd`, which you can open in GTKWave, or render as an
SVG timing diagram (no extra tools needed):

```powershell
python tools/vcd2svg.py build/dump.vcd build/my_wave.svg --width 2200 --scale 40
```

## Troubleshooting

* **`iverilog: command not found`** -- close and reopen the terminal after
  editing PATH; check the path you added points at the `bin` folder.
* **Simulation hangs** -- raise the timeout
  (`vvp ... +TIMEOUT=500000`) or make sure you pass both `+HEX=` and
  `+DATA=`.
* **Yosys out of memory on `run_synth.py`** -- close other programs; the SoC
  runs each take a few hundred MB.
* **Antivirus complains about `vvp.exe`** -- common false positive for the
  Icarus interpreter; add an exclusion for the install folder.

That is everything. `docs/REPORT.md` explains what the tools are actually
running and what all the numbers mean.

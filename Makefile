PY ?= python3
BUILD := build
IVERILOG ?= iverilog
VVP ?= vvp
IVFLAGS := -g2012
FILTER := 2>&1 | grep -v "sorry: constant"

BASIC := rtl/basic/and_gate.sv rtl/basic/mux.sv rtl/basic/register.sv rtl/basic/counter.sv
CORES := rtl/core/alu.sv rtl/core/regfile.sv rtl/core/imm_gen.sv rtl/core/decoder.sv
MEM := rtl/mem/imem.sv rtl/mem/dmem.sv
PERIPH := rtl/periph/uart_tx.sv rtl/periph/uart_rx.sv rtl/periph/uart.sv rtl/periph/timer.sv
CUSTOM := rtl/custom/dotp.sv

CORE_single := rtl/core/core_single.sv rtl/soc/soc_single.sv
CORE_multi := rtl/core/core_multi.sv rtl/soc/soc_multi.sv
CORE_pipe := rtl/core/core_pipe.sv rtl/soc/soc_pipe.sv

.PHONY: all test bench synth figures wave clean

all: test

test:
	$(PY) tools/run_tests.py

bench:
	$(PY) tools/run_bench.py

synth:
	$(PY) tools/run_synth.py

figures:
	$(PY) tools/make_charts.py

wave: $(BUILD)/wave_single.vcd $(BUILD)/wave_pipe.vcd
	$(PY) tools/vcd2svg.py $(BUILD)/wave_single.vcd waveforms/wave_single.svg --width 2200 --scale 40
	$(PY) tools/vcd2svg.py $(BUILD)/wave_pipe.vcd waveforms/wave_pipe.svg --width 2200 --scale 36

$(BUILD)/wave_single.vcd: | $(BUILD)
	$(PY) tools/asm.py programs/asm/test_basic.s -o $(BUILD)/test_basic
	$(IVERILOG) $(IVFLAGS) -o $(BUILD)/tb_soc_single.vvp $(BASIC) $(CORES) $(MEM) $(PERIPH) $(CUSTOM) $(CORE_single) testbench/tb_soc_single.sv $(FILTER)
	$(VVP) $(BUILD)/tb_soc_single.vvp +HEX=$(BUILD)/test_basic_prog.hex +DATA=$(BUILD)/test_basic_data.hex +DUMP && mv -f $(BUILD)/dump.vcd $(BUILD)/wave_single.vcd

$(BUILD)/wave_pipe.vcd: | $(BUILD)
	$(PY) tools/asm.py programs/asm/test_dot.s -o $(BUILD)/test_dot
	$(IVERILOG) $(IVFLAGS) -o $(BUILD)/tb_soc_pipe.vvp $(BASIC) $(CORES) $(MEM) $(PERIPH) $(CUSTOM) $(CORE_pipe) testbench/tb_soc_pipe.sv $(FILTER)
	$(VVP) $(BUILD)/tb_soc_pipe.vvp +HEX=$(BUILD)/test_dot_prog.hex +DATA=$(BUILD)/test_dot_data.hex +DUMP && mv -f $(BUILD)/dump.vcd $(BUILD)/wave_pipe.vcd

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD) benchmarks/figures/*.svg waveforms/*.svg

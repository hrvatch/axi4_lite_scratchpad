.PHONY: jg clean sim_batch sim_gui

XRUN_ARGS=
XRUN_ARGS+= -access +rwc 
XRUN_ARGS+= -sv
XRUN_ARGS+= $(AXI_LITE_SCRATCHPAD_PATH)/rtl/axi_lite_scratchpad.sv
XRUN_ARGS+= $(AXI_LITE_SCRATCHPAD_PATH)/tb/axi_lite_scratchpad_sim_tb.sv
XRUN_ARGS+= -top axi_lite_scratchpad_sim_tb -64bit
XRUN_ARGS+= -64bit
XRUN_ARGS+= -timescale 1ns/1ps
XRUN_ARGS+= -errormax 10
XRUN_ARGS+= -nowarn CUVWSP

jg:
	jg $(AXI_LITE_SCRATCHPAD_PATH)/formal/tc/axi_lite_scratchpad_tc.tcl

sim_batch:
	xrun $(XRUN_ARGS)

sim_gui:
	xrun $(XRUN_ARGS) -gui -input $(AXI_LITE_SCRATCHPAD_PATH)/sim/probe.tcl

clean:
	rm -rf jgproject

help:
	@echo "Available targets:"
	@echo "  jg        - Start Jasper FPV"
	@echo "  sim_batch - Start Xcelium in batch mode"
	@echo "  sim_gui   - Start Xcelium in gui mode"
	@echo "  clean     - Remove simulation artefacts"

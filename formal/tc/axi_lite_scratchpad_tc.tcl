clear -all
analyze -sv12 $env(AXI_LITE_SCRATCHPAD_PATH)/formal/src/axi_lite_scratchpad_tb.sv $env(AXI_LITE_SCRATCHPAD_PATH)/rtl/axi_lite_scratchpad.sv
elaborate -top axi_lite_scratchpad_tb
clock clk
reset !rst_n 


clear -all
analyze -sv12 $env(AXI_LITE_SCRATCHPAD_PATH)/formal/src/axi_lite_scratchpad_tb.sv $env(AXI_LITE_SCRATCHPAD_PATH)/rtl/axi_lite_scratchpad.sv
elaborate -top axi_lite_scratchpad_tb
assume { axi_lite_scratchpad_dut.ram_block[3] == 32'hdead }
assume { axi_lite_scratchpad_dut.ram_block[2] == 32'hbeef }
assume { axi_lite_scratchpad_dut.ram_block[1] == 32'hc0ca }
assume { axi_lite_scratchpad_dut.ram_block[0] == 32'hc01a }
clock clk
reset !rst_n 


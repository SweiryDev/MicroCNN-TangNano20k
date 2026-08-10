//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-08-10 15:02:00
//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
create_generated_clock -name system_clk -source [get_ports {clk}] -master_clock clk -divide_by 9 -multiply_by 10 [get_nets {system_clk}]
create_generated_clock -name npu_clk -source [get_nets {system_clk}] -master_clock system_clk -divide_by 1 -multiply_by 1 [get_nets {npu_clk}]
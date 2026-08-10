//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Device Version: C
//Created Time: Mon Aug  3 15:28:19 2026

module Gowin_DCS (clkout, clksel, clk0, clk1, clk2, clk3);

output clkout;
input [3:0] clksel;
input clk0;
input clk1;
input clk2;
input clk3;

wire gw_gnd;

assign gw_gnd = 1'b0;

DCS dcs_inst (
    .CLKOUT(clkout),
    .CLKSEL(clksel),
    .CLK0(clk0),
    .CLK1(clk1),
    .CLK2(clk2),
    .CLK3(clk3),
    .SELFORCE(gw_gnd)
);

defparam dcs_inst.DCS_MODE = "CLK0_GND";

endmodule //Gowin_DCS

//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Device Version: C
//Created Time: Thu Jul 23 15:06:08 2026

module Gowin_MULT (dout, a, b);

output [16:0] dout;
input [8:0] a;
input [7:0] b;

wire [0:0] dout_w;
wire [8:0] soa_w;
wire [8:0] sob_w;
wire gw_vcc;
wire gw_gnd;

assign gw_vcc = 1'b1;
assign gw_gnd = 1'b0;

MULT9X9 mult9x9_inst (
    .DOUT({dout_w[0],dout[16:0]}),
    .SOA(soa_w),
    .SOB(sob_w),
    .A(a),
    .B({b[7],b[7:0]}),
    .ASIGN(gw_vcc),
    .BSIGN(gw_vcc),
    .SIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .SIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .CE(gw_gnd),
    .CLK(gw_gnd),
    .RESET(gw_gnd),
    .ASEL(gw_gnd),
    .BSEL(gw_gnd)
);

defparam mult9x9_inst.AREG = 1'b0;
defparam mult9x9_inst.BREG = 1'b0;
defparam mult9x9_inst.OUT_REG = 1'b0;
defparam mult9x9_inst.PIPE_REG = 1'b0;
defparam mult9x9_inst.ASIGN_REG = 1'b0;
defparam mult9x9_inst.BSIGN_REG = 1'b0;
defparam mult9x9_inst.SOA_REG = 1'b0;
defparam mult9x9_inst.MULT_RESET_MODE = "SYNC";

endmodule //Gowin_MULT

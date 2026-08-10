//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Device Version: C
//Created Time: Thu Jul 23 13:24:29 2026

module gowin_sdpb_fc1 (dout, clka, cea, reseta, clkb, ceb, resetb, oce, ada, din, adb);

output [63:0] dout;
input clka;
input cea;
input reseta;
input clkb;
input ceb;
input resetb;
input oce;
input [8:0] ada;
input [7:0] din;
input [5:0] adb;

wire gw_gnd;

assign gw_gnd = 1'b0;

SDPB sdpb_inst_0 (
    .DO({dout[59:56],dout[51:48],dout[43:40],dout[35:32],dout[27:24],dout[19:16],dout[11:8],dout[3:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({gw_gnd,gw_gnd,gw_gnd}),
    .BLKSELB({gw_gnd,gw_gnd,gw_gnd}),
    .ADA({gw_gnd,gw_gnd,gw_gnd,ada[8:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[3:0]}),
    .ADB({gw_gnd,gw_gnd,gw_gnd,adb[5:0],gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd})
);

defparam sdpb_inst_0.READ_MODE = 1'b0;
defparam sdpb_inst_0.BIT_WIDTH_0 = 4;
defparam sdpb_inst_0.BIT_WIDTH_1 = 32;
defparam sdpb_inst_0.BLK_SEL_0 = 3'b000;
defparam sdpb_inst_0.BLK_SEL_1 = 3'b000;
defparam sdpb_inst_0.RESET_MODE = "SYNC";

SDPB sdpb_inst_1 (
    .DO({dout[63:60],dout[55:52],dout[47:44],dout[39:36],dout[31:28],dout[23:20],dout[15:12],dout[7:4]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({gw_gnd,gw_gnd,gw_gnd}),
    .BLKSELB({gw_gnd,gw_gnd,gw_gnd}),
    .ADA({gw_gnd,gw_gnd,gw_gnd,ada[8:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:4]}),
    .ADB({gw_gnd,gw_gnd,gw_gnd,adb[5:0],gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd})
);

defparam sdpb_inst_1.READ_MODE = 1'b0;
defparam sdpb_inst_1.BIT_WIDTH_0 = 4;
defparam sdpb_inst_1.BIT_WIDTH_1 = 32;
defparam sdpb_inst_1.BLK_SEL_0 = 3'b000;
defparam sdpb_inst_1.BLK_SEL_1 = 3'b000;
defparam sdpb_inst_1.RESET_MODE = "SYNC";

endmodule //gowin_sdpb_fc1

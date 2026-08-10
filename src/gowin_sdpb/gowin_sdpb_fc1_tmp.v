//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.03 Education
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Device Version: C
//Created Time: Thu Jul 23 13:24:29 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    gowin_sdpb_fc1 your_instance_name(
        .dout(dout), //output [63:0] dout
        .clka(clka), //input clka
        .cea(cea), //input cea
        .reseta(reseta), //input reseta
        .clkb(clkb), //input clkb
        .ceb(ceb), //input ceb
        .resetb(resetb), //input resetb
        .oce(oce), //input oce
        .ada(ada), //input [8:0] ada
        .din(din), //input [7:0] din
        .adb(adb) //input [5:0] adb
    );

//--------Copy end-------------------

//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Device Version: C
//Created Time: Mon Aug  3 15:07:42 2026

module Gowin_DHCEN (clkout, clkin, ce);

output clkout;
input clkin;
input ce;

DHCEN dhcen_inst (
    .CLKOUT(clkout),
    .CLKIN(clkin),
    .CE(ce)
);

endmodule //Gowin_DHCEN

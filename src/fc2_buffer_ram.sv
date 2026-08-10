`timescale 1ns/1ps

// Wraps the asymmetric Gowin SDPB IP for the FC1 -> FC2 handoff.
// Port A (Write): 8-bit width, 32 depth (Driven by FC1)
// Port B (Read): 64-bit width, 4 depth (Driven by FC2 TDM array)

module fc2_buffer_ram (
    input  logic        clk,
    input  logic        rst,
    
    // Write Interface (Driven by FC1)
    input  logic        we,      // Write enable (from fc2_ram_we)
    input  logic [4:0]  waddr,   // Write address: 0 to 31
    input  logic [7:0]  wdata,   // 8-bit output from FC1
    
    // Read Interface (Driven by FC2 FSM)
    input  logic [1:0]  raddr,   // Read address: 0 to 3
    output logic [63:0] rdata    // 64-bit chunk (8 parallel inputs for FC2)
);

    gowin_sdpb_fc2 u_sdpb (
        .clka(clk),
        .cea(we),
        .reseta(rst),
        .ada(waddr),        // 5-bit write address maps natively
        .din(wdata),        // 8-bit write data from FC1
        .clkb(clk),
        .ceb(1'b1),
        .resetb(rst),
        .oce(1'b1),
        .adb(raddr),        // 2-bit read address maps natively
        .dout(rdata)        // 64-bit read data out to FC2 array
    );

endmodule
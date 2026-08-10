`timescale 1ns/1ps

// Wraps the asymmetric Gowin SDPB IP.
// Port A (Write): 8-bit width, 512 depth (uses 0-399)
// Port B (Read): 64-bit width, 64 depth (uses 0-49)

module fc1_buffer_ram (
    input  logic        clk,
    input  logic        rst,
    
    // Write Interface (Driven by MaxPool2)
    input  logic        we,      // Write enable (pool2_valid)
    input  logic [7:0]  wdata,   // Pixel data (pool2_out)
    
    // Read Interface (Driven by Debug UI / FC1 Layer)
    input  logic [5:0]  raddr,   // Read address (0 to 49)
    output logic [63:0] rdata    // 64-bit output chunk (8 pixels)
);

    // Auto-incrementing write address (0 to 399)
    logic [8:0] waddr;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            waddr <= 9'd0;
        end else if (we && waddr < 9'd400) begin
            waddr <= waddr + 1'b1;
        end
    end

    // Asymmetric BRAM Instantiation
    gowin_sdpb_fc1 u_sdpb (
        .clka(clk),
        .cea(we),
        .reseta(rst),
        .ada(waddr),        // 9-bit write address
        .din(wdata),        // 8-bit write data
        .clkb(clk),
        .ceb(1'b1),
        .resetb(rst),
        .oce(1'b1),
        .adb(raddr), //  drive the lower 6 bit
        .dout(rdata)        // 64-bit read data
    );

endmodule
`timescale 1ns/1ps

// Dual-Port Image RAM (Input)
// Port A (Write): Synchronous to system_clk (UART Rx side)
// Port B (Read):  Synchronous to npu_clk (NPU Datapath side)

module img_ram (
    // Write Port (UART side)
    input  logic        wr_clk,
    input  logic        we,
    input  logic [9:0]  waddr,
    input  logic [23:0] wdata, // {Red, Green, Blue}

    // Read Port (NPU side)
    input  logic        rd_clk,
    input  logic        re,
    input  logic [9:0]  raddr,
    output logic [23:0] rdata
);

    // 1024 depth to safely cover the 28x28 (784) image size
    logic [23:0] mem [0:1023];

    // Write Port (Synchronous to UART/System clock)
    always_ff @(posedge wr_clk) begin
        if (we) begin
            mem[waddr] <= wdata;
        end
    end

    // Read Port (Synchronous to Gated NPU clock)
    always_ff @(posedge rd_clk) begin
        if (re) begin
            rdata <= mem[raddr];
        end
    end

endmodule
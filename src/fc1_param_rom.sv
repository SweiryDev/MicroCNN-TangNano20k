`timescale 1ns/1ps

// Unified parameter memory for FC1. Uses $readmemh with a 64-bit wide array 

module fc1_param_rom (
    input  logic        clk,
    input  logic        en,           
    input  logic [10:0] weight_addr,  // 0 to 1599 (32 neurons * 50 chunks)
    input  logic [4:0]  bias_addr,    // 0 to 31 (for 32 output neurons)
    
    output logic [63:0] weights_out,  // 8 parallel 8-bit weights
    output logic [31:0] bias_out      // 32-bit bias value
);

    // Internal Memories
    logic [63:0] weight_mem [0:1599];
    logic [31:0] bias_mem   [0:31];
    
    initial begin
        $readmemh("hardware_roms/fc1_weights_64b.hex", weight_mem);
        $readmemh("hardware_roms/fc1_biases.hex", bias_mem);
    end

    // Synchronous Read 
    always_ff @(posedge clk) begin
        if (en) begin
            weights_out <= weight_mem[weight_addr];
            bias_out    <= bias_mem[bias_addr];
        end
    end

endmodule
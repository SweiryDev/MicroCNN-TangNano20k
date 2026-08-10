`timescale 1ns/1ps

// Encapsulates the weight and bias ROMs for Layer 1. 
// Handles the flattening, reading, and 3D repacking of the weights
// to keep the top-level integration clean.

module conv1_param_rom (
    input  logic        clk,
    input  logic        weight_en,
    input  logic        bias_en,
    input  logic [2:0]  filter_idx, // 0 to 7
    
    output logic [7:0]  npu_weights [0:3][0:2][0:2],
    output logic [31:0] bias_out
);

    // Internal Memories
    logic [7:0]  weight_mem [0:215];
    logic [31:0] bias_mem   [0:7];
    
    logic [215:0] weight_read_data;

    initial begin
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_roms/conv1_weights.hex", weight_mem);
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_roms/conv1_biases.hex", bias_mem);
    end

    // Flattening (Forcing LUT implementation over BRAM)
    logic [1727:0] flat_weights;
    genvar w;
    generate
        for (w = 0; w < 216; w++) begin : flatten_weights
            assign flat_weights[w*8 +: 8] = weight_mem[w];
        end
    endgenerate

    // Synchronous Read
    always_ff @(posedge clk) begin
        if (weight_en) begin
            weight_read_data <= flat_weights[filter_idx * 216 +: 216];
        end
        if (bias_en) begin
            bias_out <= bias_mem[filter_idx];
        end
    end

    // 3D Unpacking (Routing to the NPU format)
    always_comb begin
        // Zero out everything first (handles the unused 4th channel)
        for (int c = 0; c < 4; c++) begin
            for (int r = 0; r < 3; r++) begin
                for (int k = 0; k < 3; k++) begin
                    npu_weights[c][r][k] = 8'd0;
                end
            end
        end
        
        // Map the 3 active channels (CHW to HWC handling)
        for (int r = 0; r < 3; r++) begin        
            for (int k = 0; k < 3; k++) begin    
                for (int c = 0; c < 3; c++) begin 
                    npu_weights[c][r][k] = weight_read_data[(r*9 + k*3 + c)*8 +: 8];
                end
            end
        end
    end

endmodule
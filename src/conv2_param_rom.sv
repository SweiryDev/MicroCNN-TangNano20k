`timescale 1ns/1ps

// Encapsulates the weight and bias ROMs for Layer 2. 
// Restored to use a synchronous (always_ff) read with weight_en
// and bias_en to maintain architectural parity with Layer 1.

module conv2_param_rom (
    input  logic        clk,
    input  logic        weight_en,  
    input  logic        bias_en,    
    input  logic [3:0]  filter_idx, // 0 to 15
    input  logic        chunk_sel,  // 0 = Ch 0-3, 1 = Ch 4-7
    
    output logic [7:0]  npu_weights [0:3][0:2][0:2],
    output logic [31:0] bias_out
);

    // Internal Memories (16 Filters * 8 Channels * 9 Weights = 1152 Bytes)
    logic [7:0]  weight_mem [0:1151];
    logic [31:0] bias_mem   [0:15];
    
    logic [575:0] filter_read_data; 

    initial begin
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_roms/conv2_weights.hex", weight_mem);
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_roms/conv2_biases.hex", bias_mem);
    end

    // Flattening (Forcing LUT implementation over BRAM)
    logic [9215:0] flat_weights; 
    genvar w;
    generate
        for (w = 0; w < 1152; w++) begin : flatten_weights
            assign flat_weights[w*8 +: 8] = weight_mem[w];
        end
    endgenerate

    // Synchronous Read (Restored to exactly match Conv1 architecture)
    always_ff @(posedge clk) begin
        if (weight_en) begin
            // Read 576 bits (72 bytes) starting at the current filter index
            filter_read_data <= flat_weights[filter_idx * 576 +: 576];
        end
        if (bias_en) begin
            bias_out <= bias_mem[filter_idx];
        end
    end

    // 3D Unpacking & Chunk Multiplexing
    logic [3:0] active_channel;

    always_comb begin
        for (int r = 0; r < 3; r++) begin        
            for (int k = 0; k < 3; k++) begin    
                for (int c = 0; c < 4; c++) begin 
                    
                    if (chunk_sel == 1'b1) begin
                        active_channel = c + 4;
                    end else begin
                        active_channel = c;
                    end
                    
                    npu_weights[c][r][k] = filter_read_data[(r*24 + k*8 + active_channel)*8 +: 8];
                    
                end
            end
        end
    end

endmodule
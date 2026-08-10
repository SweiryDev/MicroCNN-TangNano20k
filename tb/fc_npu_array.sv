`timescale 1ns/1ps

// Behavioral model of the 8-lane DSP compute engine for ModelSim.
// Replicates the Gowin MULTALU Accum+A*B mode and perfectly matches
// the 2-stage internal pipeline latency (Mult Reg -> Accum Reg) 
// expected by the FC1 FSM.

module fc_npu_array (
    input  logic        clk,
    input  logic        ce,           // Clock Enable 
    input  logic        reset,        // Synchronous clear to wipe accumulators 
    
    // 64-bit Parallel Inputs (8 lanes * 8 bits)
    input  logic [63:0] data_in,    
    input  logic [63:0] weights_in,   
    
    // 8 Parallel 32-bit Partial Sum Outputs
    output logic signed [31:0] psum_out [0:7] 
);

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : sim_lanes
            // Internal DSP Pipeline Registers
            logic signed [15:0] mult_reg;
            logic signed [31:0] accum_reg;

            always_ff @(posedge clk) begin
                if (reset) begin
                    mult_reg  <= 16'd0;
                    accum_reg <= 32'd0;
                end else if (ce) begin
                    // Stage 1: Synchronous Multiplier
                    // Cast slices to signed to ensure arithmetic multiplication
                    mult_reg <= $signed(data_in[i*8 +: 8]) * $signed(weights_in[i*8 +: 8]);
                    
                    // Stage 2: Synchronous Accumulator
                    accum_reg <= accum_reg + mult_reg;
                end
            end
            
            // Output routing
            assign psum_out[i] = accum_reg;
        end
    endgenerate

endmodule
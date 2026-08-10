`timescale 1ns/1ps

// The shared 8-lane DSP compute engine for the Fully Connected layers.
// Instantiates 8 Gowin MULTALU blocks in Accum+A*B mode.
// Completely decoupled from state machines to allow TDM reuse 
// between FC1 and FC2.


module fc_npu_array_gowin (
    input  logic        clk,
    input  logic        ce,           // Clock Enable (Held high during the 50-cycle loop)
    input  logic        reset,        // Synchronous clear to wipe accumulators (Active High)
    
    // 64-bit Parallel Inputs (8 lanes * 8 bits)
    input  logic [63:0] data_in,    
    input  logic [63:0] weights_in,   
    
    // 8 Parallel 32-bit Partial Sum Outputs
    output logic signed [31:0] psum_out [0:7] 
);

    // -- DSP MULTALU Array (8 Vertical Lanes) --
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : pe_lanes
            logic signed [53:0] dout_full;

            // Instantiating the Gowin IP MULTALU
            dsp_multalu_accum u_dsp (
                .clk(clk),
                .ce(ce),
                .reset(reset),
                .accload(1'b1),                       
                .a(data_in[i*8 +: 8]),                // 8-bit Data Lane
                .b(weights_in[i*8 +: 8]),             // 8-bit Weight Lane
                .c(32'd0),                            // Tie +C to 0 for pure Accum+A*B
                .dout(dout_full),                     // 54-bit raw output
                .caso()                               // Unconnected (No horizontal cascading)
            );
            
            // Slice the lower 32 bits for the reduction tree
            assign psum_out[i] = dout_full[31:0];
        end
    endgenerate

endmodule
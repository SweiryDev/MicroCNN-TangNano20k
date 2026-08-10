`timescale 1ns/1ps

module fc2_reduction_tree (
    input  logic signed [31:0] psum_lanes [0:7],
    input  logic signed [31:0] bias_in,
    
    // Raw 32-bit sum routed directly to Argmax
    output logic signed [31:0] fc2_out_32b 
);

    always_comb begin
        // Combinatorial adder tree for the 8 lanes + bias
        fc2_out_32b = psum_lanes[0] + 
                      psum_lanes[1] + 
                      psum_lanes[2] + 
                      psum_lanes[3] + 
                      psum_lanes[4] + 
                      psum_lanes[5] + 
                      psum_lanes[6] + 
                      psum_lanes[7] + 
                      bias_in;
    end

endmodule
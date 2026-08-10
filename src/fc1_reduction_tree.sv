`timescale 1ns/1ps

// Combinatorial reduction tree for the FC1 layer. Sums the 8 
// vertical lanes, adds the bias, applies scaling (divide by 512), 
// and executes the ReLU/clamping activation function.

module fc1_reduction_tree (
    // Inputs from NPU Array
    input  logic signed [31:0] psum_lanes [0:7],
    
    // Input from Parameter ROM
    input  logic signed [31:0] bias_in,
    
    // Output to FC2 Buffer RAM (Data only)
    output logic [7:0]         fc2_wdata
);

    // Combinatorial Adder Tree
    logic signed [31:0] sum_A, sum_B, sum_C, sum_D;
    logic signed [31:0] sum_AB, sum_CD;
    logic signed [31:0] final_32b_sum;
    logic signed [31:0] shifted_sum;

    always_comb begin
        // First Adder Layer (Collapse 8 lanes to 4)
        sum_A = psum_lanes[0] + psum_lanes[1];
        sum_B = psum_lanes[2] + psum_lanes[3];
        sum_C = psum_lanes[4] + psum_lanes[5];
        sum_D = psum_lanes[6] + psum_lanes[7];
        
        // Second Adder Layer (Collapse 4 lanes to 2)
        sum_AB = sum_A + sum_B;
        sum_CD = sum_C + sum_D;
        
        // Final Sum + Bias (Collapse 2 lanes and add bias)
        final_32b_sum = sum_AB + sum_CD + bias_in;
        
        // Scale (Arithmetic Shift Right by 9 = divide by 512)
        shifted_sum = final_32b_sum >>> 9;
        
        // ReLU and Clamp (Saturate to INT8 limits: 0 to 127)
        if (shifted_sum < 0) begin
            fc2_wdata = 8'd0;
        end else if (shifted_sum > 127) begin
            fc2_wdata = 8'd127;
        end else begin
            fc2_wdata = shifted_sum[7:0];
        end
    end

endmodule
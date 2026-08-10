`timescale 1ns/1ps

// Multi-channel wrapper for the 3x3 spatial MACs.
// Handles the centralized Bias, Scaling, ReLU, and Pipeline Register.
// Upgraded with a partial_sum_reg to support Time-Multiplexed Folding.

module ws_conv_core #(
    parameter NUM_CORES = 4 
)(
    input logic clk,
    input logic rst,
    input logic compute_en, // Handshake, high when data_in is valid
    input logic accumulate, // 0 = start fresh sum (with bias), 1 = add to partial sum
    
    // Data and Weights for all cores (3D Arrays) [channel][row][column]
    input logic [7:0]  data_in [0:NUM_CORES-1][0:2][0:2],
    input logic [7:0]  weight_in [0:NUM_CORES-1][0:2][0:2],
    
    // Layer Parameters
    input logic [31:0] bias_in,
    input logic [3:0]  shift_val,
    
    // Output
    output logic [7:0]  mac_out,
    output logic        valid_out,

    // --- DEBUG PORTS ---
    output logic signed [31:0] dbg_mac_0,    // Stage 1: Raw Red Channel Sum
    output logic signed [31:0] dbg_acc,      // Stage 2: Pre-Shift Total Accumulator
    output logic signed [31:0] dbg_shifted   // Stage 3: Post-Shift Accumulator
);

    // Array to hold the raw 32-bit outputs from each of the 4 sub-modules
    logic signed [31:0] mac_in [0:NUM_CORES-1];
    
    // The Math Cores
    genvar i;
    generate
        for (i=0; i<NUM_CORES; i=i+1) begin : mac_cores
            spatial_3x3_mac u_mac (
                .data_in(data_in[i]),
                .weight_in(weight_in[i]),
                .mac_out(mac_in[i])
            );
        end
    endgenerate

    // The Accumulator & Post-Processing
    logic signed [31:0] mac_sum;
    logic signed [31:0] current_acc;
    logic signed [31:0] partial_sum_reg;
    
    logic signed [31:0] shifted_acc;
    logic [7:0]         relu_acc;

    // 8-bit relu-saturate function
    function automatic logic [7:0] relu_uint8(input logic signed [31:0] x);
        begin
            if (x > 32'sd255)
                relu_uint8 = 8'd255;
            else if (x < 32'sd0)
                relu_uint8 = 8'd0;
            else
                relu_uint8 = x[7:0];  // Lower 8-bit
        end
    endfunction

    always_comb begin
        // Sum the 4 active spatial MACs
        mac_sum = $signed(mac_in[0]) + 
                  $signed(mac_in[1]) + 
                  $signed(mac_in[2]) + 
                  $signed(mac_in[3]);

        // Folding Logic (Multiplex the base of the addition)
        if (accumulate) begin
            current_acc = partial_sum_reg + mac_sum;
        end else begin
            current_acc = $signed(bias_in) + mac_sum;
        end

        // Scale and ReLU
        shifted_acc = current_acc >>> shift_val;
        relu_acc = relu_uint8(shifted_acc);
    end

    // The Pipeline Register (Sequential - Timing Protection)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            partial_sum_reg <= 32'sd0;
            mac_out         <= 8'd0;
            valid_out       <= 1'b0;
        end else begin
            valid_out <= compute_en; 
            
            if (compute_en) begin
                partial_sum_reg <= current_acc; 
                mac_out         <= relu_acc;    
            end
        end
    end

    assign dbg_mac_0 = mac_in[0];
    assign dbg_acc = current_acc;
    assign dbg_shifted = shifted_acc;

endmodule
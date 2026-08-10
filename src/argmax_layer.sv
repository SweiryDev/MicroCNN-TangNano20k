`timescale 1ns/1ps

module argmax_layer (
    input  logic       clk,
    input  logic       rst,
    
    // Inputs from FC2 Datapath
    input  logic       fc2_start,      
    input  logic       fc2_valid_in,
    input  logic [2:0] current_neuron, // 0 to 7
    
    // Raw 32-bit unscaled sum from the FC2 Reduction Tree
    input  logic signed [31:0] data_in, 
    
    // Output Classification
    output logic [2:0] predicted_class,
    output logic       argmax_done
);

    logic signed [31:0] current_max_val;
    logic [2:0]         current_best_idx;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_max_val  <= 32'h8000_0000; // Most negative 32-bit signed value
            current_best_idx <= 3'd0;
            argmax_done      <= 1'b0;
        end else if (fc2_start) begin
            // Reset tracker for the new inference pass
            current_max_val  <= 32'h8000_0000;
            current_best_idx <= 3'd0;
            argmax_done      <= 1'b0;
        end else if (fc2_valid_in) begin
            // Compare incoming 32-bit sum to the current max
            if (data_in > current_max_val) begin
                current_max_val  <= data_in;
                current_best_idx <= current_neuron;
            end
            
            // If this is the final neuron (Neuron 7), lock in the prediction
            if (current_neuron == 3'd7) begin
                argmax_done <= 1'b1;
            end
        end
    end

    // Route the winning index out
    assign predicted_class = current_best_idx;

endmodule
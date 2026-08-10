`timescale 1ns/1ps

// Converts a 1D pixel stream into a 2D 3x3 spatial window.
// Contains two row-buffers. Parameterized for different image sizes.

module single_channel_line_buffer #(
    parameter IMAGE_WIDTH = 28 // Default to Conv1 width. Set to 13 for Conv2.
)(
    input logic clk,
    input logic rst,
    input logic shift_en,       // High when streaming valid pixels from memory
    input logic [7:0] data_in, // Single streaming pixel
    
    output logic [7:0] window_out [0:2][0:2] // The 3x3 spatial output
);

    // Two rows (IMAGE_WIDTH) and 3 last pixels
    logic [7:0] shift_reg [0:(2*IMAGE_WIDTH)+2]; 

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            // Reset Register
            for(int i=0;i<(2*IMAGE_WIDTH)+3; i=i+1) begin
                shift_reg[i] <= 8'd0;
            end 
        end else if(shift_en) begin
            for(int i=(2*IMAGE_WIDTH)+2; i>0; i=i-1) begin
                shift_reg[i] <= shift_reg[i-1]; // shift line buffer
            end

            shift_reg[0] <= data_in; // newest pixel
        end
    end

    always_comb begin
        // Default window values
        for(int r=0; r<3; r=r+1) begin
            for(int c=0; c<3; c=c+1) begin
                window_out[r][c] = 8'd0;
            end
        end

        window_out[0][0] = shift_reg[(2*IMAGE_WIDTH)+2]; // Oldest Pixel in line (First in memory)
        window_out[0][1] = shift_reg[(2*IMAGE_WIDTH)+1];
        window_out[0][2] = shift_reg[(2*IMAGE_WIDTH)];
        
        window_out[1][0] = shift_reg[IMAGE_WIDTH+2];
        window_out[1][1] = shift_reg[IMAGE_WIDTH+1];
        window_out[1][2] = shift_reg[IMAGE_WIDTH];

        window_out[2][0] = shift_reg[2];
        window_out[2][1] = shift_reg[1];
        window_out[2][2] = shift_reg[0]; // Newest Pixel in line (Last in memory)
    end

endmodule
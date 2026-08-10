`timescale 1ns/1ps

// Streams a IN_WIDTHxIN_WIDTH feature map and outputs a OUT_WIDTHxOUT_WIDTH max-pooled map.
// Uses a 1-row FIFO to align the 2x2 spatial windows.

module maxpool2x2 #(
    parameter IN_WIDTH = 26, // Input feature map width
    parameter OUT_WIDTH = 13 // Output feature map width (IN_WIDTH / 2)
)(
    input logic clk,
    input logic rst,
    
    input logic valid_in, // High when NPU provides a valid pixel
    input logic [7:0] data_in,  // 8-bit output from the ws_conv_core
    
    output logic valid_out, // High when a 2x2 max is computed
    output logic [7:0] max_out // The pooled pixel
);

    // 1-Row Buffer to hold the "top" row of our 2x2 window
    logic [7:0] row_buffer [0:IN_WIDTH-1];
    
    // Coordinate tracking
    logic [7:0] col_count; 
    logic row_parity; // 0 = Top row of 2x2, 1 = Bottom row of 2x2
    
    // Registers to hold the left-side pixels of the 2x2 window
    logic [7:0] top_left;
    logic [7:0] bottom_left;

    // Temp values for the max value comparison
    logic [7:0] max_top, max_bot;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            col_count   <= 8'd0;
            row_parity  <= 1'b0;
            valid_out   <= 1'b0;
            max_out     <= 8'd0;
            top_left    <= 8'd0;
            bottom_left <= 8'd0;
            for (int i = 0; i < IN_WIDTH; i++) row_buffer[i] <= 8'd0;
        end else begin
            // Default, don't output anything unless we finish a 2x2 block
            valid_out <= 1'b0; 
            
            if (valid_in) begin
                // Shift the row buffer
                for (int i = IN_WIDTH-1; i > 0; i--) begin
                    row_buffer[i] <= row_buffer[i-1];
                end
                row_buffer[0] <= data_in;
                
                // "bottom" row (row_parity == 1) 
                // and the "right" column (col_count is odd)
                if (row_parity == 1'b1 && col_count[0] == 1'b1) begin
                    // 4 pixels:
                    // top_left, saved from previous clock cycle
                    // bottom_left, saved from previous clock cycle
                    // top_right, row_buffer[IN_WIDTH-1] (delayed by 1 row)
                    // bottom_right, data_in (newest pixel)
                    
                    max_top = (top_left > row_buffer[IN_WIDTH-1]) ? top_left : row_buffer[IN_WIDTH-1];
                    max_bot = (bottom_left > data_in) ? bottom_left : data_in;
                    
                    max_out   <= (max_top > max_bot) ? max_top : max_bot;
                    valid_out <= 1'b1;
                end
                
                // Save the left-side pixels for the next clock cycle
                top_left    <= row_buffer[IN_WIDTH-1];
                bottom_left <= data_in;
                
                // Update coordinates
                if (col_count == IN_WIDTH - 1) begin
                    col_count  <= 8'd0;
                    row_parity <= ~row_parity;
                end else begin
                    col_count <= col_count + 1'b1;
                end
            end
        end
    end

endmodule
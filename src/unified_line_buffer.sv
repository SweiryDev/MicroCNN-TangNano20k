`timescale 1ns/1ps

// Multi-channel wrapper for the single_channel_line_buffer module.
// Instantiates multiple 1D->2D buffers to create a 3D volume
// of pixels (Channels*3*3) to feed the NPU core.

module unified_line_buffer #(
    parameter NUM_CHANNELS = 4, // Number of parallel channels (matches NPU NUM_CORES)
    parameter IMAGE_WIDTH = 28  // Width of the image (28 for Conv1, 13 for Conv2)
)(
    input logic clk,
    input logic rst,
    
    // High when the FSM is pulling valid data from BRAM
    input logic shift_en,
    
    // Parallel pixel input
    input logic [7:0] data_in [0:NUM_CHANNELS-1],
    
    // 3D output window to feed directly into ws_conv_core
    output logic [7:0] window_out [0:NUM_CHANNELS-1][0:2][0:2]
);

    // Instantiate a single-channel buffer for every channel lane
    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i = i + 1) begin : channel_buffers
            single_channel_line_buffer #(
                .IMAGE_WIDTH(IMAGE_WIDTH)
            ) u_buffer (
                .clk(clk),
                .rst(rst),
                .shift_en(shift_en),
                .data_in(data_in[i]),      // Feed specific channels pixel
                .window_out(window_out[i])  // Extract specific channels 3x3 window
            );
        end
    endgenerate

endmodule
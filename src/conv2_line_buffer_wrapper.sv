`timescale 1ns/1ps

// Instantiates two 4-channel line buffers to handle 8 input channels.
// Uses a 3D MUX to feed 4 channels at a time to the NPU based on 
// chunk_sel, supporting Time-Multiplexed Folding.

module conv2_line_buffer_wrapper (
    input  logic       clk,
    input  logic       rst,
    input  logic       shift_en,  // Global shift for both buffers
    input  logic       chunk_sel, // 0 = Channels 0-3, 1 = Channels 4-7
    
    // Data from the 8 Conv2 Input RAMs
    input  logic [7:0] ram_data_in [0:7],
    
    // Muxed Output to the 4-core NPU
    output logic [7:0] muxed_window_out [0:3][0:2][0:2]
);

    // Split the incoming RAM data
    logic [7:0] lb_a_data_in [0:3];
    logic [7:0] lb_b_data_in [0:3];

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            lb_a_data_in[i] = ram_data_in[i];     // Channels 0-3
            lb_b_data_in[i] = ram_data_in[i+4];   // Channels 4-7
        end
    end

    // Dual Line Buffers (13x13 Feature Map Size)
    logic [7:0] lb_a_window [0:3][0:2][0:2];
    logic [7:0] lb_b_window [0:3][0:2][0:2];

    // Buffer A: Channels 0-3
    unified_line_buffer #(
        .NUM_CHANNELS(4),
        .IMAGE_WIDTH(13) // Conv2 spatial dimension is 13x13
    ) u_line_buffer_a (
        .clk(clk),
        .rst(rst),
        .shift_en(shift_en),
        .data_in(lb_a_data_in),
        .window_out(lb_a_window)
    );

    // Buffer B: Channels 4-7
    unified_line_buffer #(
        .NUM_CHANNELS(4),
        .IMAGE_WIDTH(13)
    ) u_line_buffer_b (
        .clk(clk),
        .rst(rst),
        .shift_en(shift_en),
        .data_in(lb_b_data_in),
        .window_out(lb_b_window)
    );

    // 3D Multiplexer
    always_comb begin
        if (chunk_sel == 1'b0) begin
            // Route Buffer A to the NPU
            for (int c = 0; c < 4; c++) begin
                for (int r = 0; r < 3; r++) begin
                    for (int k = 0; k < 3; k++) begin
                        muxed_window_out[c][r][k] = lb_a_window[c][r][k];
                    end
                end
            end
        end else begin
            // Route Buffer B to the NPU
            for (int c = 0; c < 4; c++) begin
                for (int r = 0; r < 3; r++) begin
                    for (int k = 0; k < 3; k++) begin
                        muxed_window_out[c][r][k] = lb_b_window[c][r][k];
                    end
                end
            end
        end
    end

endmodule
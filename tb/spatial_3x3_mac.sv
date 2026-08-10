`timescale 1ns/1ps

// Single channel 3x3 spatial, weight stationary multiplier for conv layers.

module spatial_3x3_mac (
    input logic [7:0] data_in [0:2][0:2], // always positive - uint8
    input logic [7:0] weight_in [0:2][0:2], // 8-bit positive/negative - int8

    output logic [31:0] mac_out // 32-bit multiply accumulate output
);

    logic signed [31:0] acc;

    logic signed [8:0] i_s;
    logic signed [8:0] w_s;

    // Single channel 3x3 spatial multiplier 
    always_comb begin
        // Initialize accumulator
        acc = 32'sd0;

        for(int r=0; r<3; r=r+1) begin
            for(int c=0; c<3; c=c+1) begin
                i_s = $signed({1'b0, data_in[r][c]}); // force positive signed value
                w_s = $signed({weight_in[r][c][7] , weight_in[r][c]}); // force sign

                acc = acc + (i_s * w_s);
            end
        end
    end

    assign mac_out = acc;

endmodule
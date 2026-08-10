`timescale 1ns/1ps

// Hard-silicon DSP spatial multiplier. Bypasses Gowin Synthesis 
// RTL inference bugs by explicitly instantiating the Multiplier IP.

module spatial_3x3_mac_gowin (
    input logic [7:0] data_in [0:2][0:2], // Unsigned pixels
    input logic [7:0] weight_in [0:2][0:2], // Signed weights
    output logic signed [31:0] mac_out
);

    // Output of a 9-bit * 8-bit signed multiplication is 17 bits
    logic signed [16:0] prod [0:2][0:2];

    genvar r, c;
    generate
        for (r = 0; r < 3; r++) begin : gen_row
            for (c = 0; c < 3; c++) begin : gen_col
                
                // Explicitly instantiate the Gowin Multiplier IP
                // A: 9-bit Signed (Zero-padded image pixel)
                // B: 8-bit Signed (Weight)
                Gowin_MULT u_mult (
                    .a({1'b0, data_in[r][c]}), 
                    .b(weight_in[r][c]),      
                    .dout(prod[r][c])
                );

            end
        end
    endgenerate

    // Balanced Adder Tree
    logic signed [31:0] sum_row_0;
    logic signed [31:0] sum_row_1;
    logic signed [31:0] sum_row_2;

    always_comb begin
        sum_row_0 = 32'(prod[0][0]) + 32'(prod[0][1]) + 32'(prod[0][2]);
        sum_row_1 = 32'(prod[1][0]) + 32'(prod[1][1]) + 32'(prod[1][2]);
        sum_row_2 = 32'(prod[2][0]) + 32'(prod[2][1]) + 32'(prod[2][2]);
    end

    assign mac_out = sum_row_0 + sum_row_1 + sum_row_2;

endmodule
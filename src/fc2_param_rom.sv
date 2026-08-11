`timescale 1ns/1ps

module fc2_param_rom (
    input  logic        clk,
    input  logic        en,
    input  logic [4:0]  weight_addr,
    input  logic [2:0]  bias_addr,  
    output logic [63:0] weights_out,
    output logic [31:0] bias_out
);

    logic [63:0] weight_mem [0:31];
    logic [31:0] bias_mem   [0:7];

    initial begin
        $readmemh("hardware_roms/fc2_weights_64b.hex", weight_mem);
        $readmemh("hardware_roms/fc2_biases.hex", bias_mem);
    end

    // Pure, standard ROM logic
    always_ff @(posedge clk) begin
        if (en) begin
            weights_out <= weight_mem[weight_addr];
            bias_out    <= bias_mem[bias_addr];
        end
    end

endmodule
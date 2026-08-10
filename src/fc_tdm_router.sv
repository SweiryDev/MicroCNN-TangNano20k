`timescale 1ns/1ps

// Encapsulates the shared FC NPU array and multiplexes FC1 and FC2 
// data/control into it based on the master pipeline state.

module fc_tdm_router (
    input  logic        clk,
    input  logic        rst,
    
    // Master Layer State: 0 = FC1 Active, 1 = FC2 Active
    input  logic        fc_layer_state, 

    // FC1 Inputs 
    input  logic        fc1_mult_ce,
    input  logic        fc1_mult_clear,
    input  logic [63:0] fc1_rdata,
    input  logic [63:0] fc1_weight_rdata,

    // FC2 Inputs
    input  logic        fc2_mult_ce,
    input  logic        fc2_mult_clear,
    input  logic [63:0] fc2_rdata,
    input  logic [63:0] fc2_weight_rdata,

    // Shared NPU Output
    output logic signed [31:0] psum_lanes_out [0:7]
);

    // Internal routed signals
    logic        npu_mult_ce_raw;
    logic        npu_mult_ce_d;
    logic        npu_mult_clear;
    logic [63:0] npu_data_in;
    logic [63:0] npu_weight_in;

    // Multiplexer Logic
    always_comb begin
        if (fc_layer_state == 1'b0) begin
            // Route FC1 to NPU
            npu_mult_ce_raw = fc1_mult_ce;
            npu_mult_clear  = fc1_mult_clear;
            npu_data_in     = fc1_rdata;
            npu_weight_in   = fc1_weight_rdata;
        end else begin
            // Route FC2 to NPU
            npu_mult_ce_raw = fc2_mult_ce;
            npu_mult_clear  = fc2_mult_clear;
            npu_data_in     = fc2_rdata;
            npu_weight_in   = fc2_weight_rdata;
        end
    end

    // 1-Cycle RAM Delay Alignment (Cleanly absorbed from top.sv)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) npu_mult_ce_d <= 1'b0;
        else     npu_mult_ce_d <= npu_mult_ce_raw;
    end

    // Instantiate the shared DSP array internally
    fc_npu_array_gowin u_shared_fc_npu (
        .clk(clk),
        .ce(npu_mult_ce_d), 
        .reset(npu_mult_clear),
        .data_in(npu_data_in),
        .weights_in(npu_weight_in),
        .psum_out(psum_lanes_out)
    );

endmodule
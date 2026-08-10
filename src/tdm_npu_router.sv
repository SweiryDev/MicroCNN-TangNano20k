`timescale 1ns/1ps

// Time-Division Multiplexing (TDM) Router for the NPU.
// Hot-swaps inputs to the shared ws_conv_core_gowin between Layer 1
// and Layer 2 based on the layer_state flag. Demultiplexes and 
// gates the output valid signals.

module tdm_npu_router (
    input  logic        clk,
    input  logic        rst,
    
    // Control Flag (from Master FSM)
    input  logic        layer_state, // 0 = Conv1, 1 = Conv2
    
    // Conv1 Inputs
    input  logic        conv1_compute_en,
    input  logic [7:0]  conv1_data_in [0:3][0:2][0:2],
    input  logic [7:0]  conv1_weight_in [0:3][0:2][0:2],
    input  logic [31:0] conv1_bias_in,
    
    // Conv2 Inputs
    input  logic        conv2_compute_en,
    input  logic        conv2_accumulate,
    input  logic [7:0]  conv2_data_in [0:3][0:2][0:2],
    input  logic [7:0]  conv2_weight_in [0:3][0:2][0:2],
    input  logic [31:0] conv2_bias_in,
    
    // Shared NPU Output
    output logic [7:0]  npu_out,
    
    // Demultiplexed Valid Signals
    output logic        conv1_valid_out,
    output logic        conv2_valid_out_gated
);

    // TDM MUX Routing Logic
    logic        mux_compute_en;
    logic        mux_accumulate;
    logic [7:0]  mux_data_in [0:3][0:2][0:2];
    logic [7:0]  mux_weight_in [0:3][0:2][0:2];
    logic [31:0] mux_bias_in;
    logic [3:0]  mux_shift_val;

    always_comb begin
        if (layer_state == 1'b0) begin
            // Route Conv1 Signals
            mux_compute_en = conv1_compute_en;
            mux_accumulate = 1'b0;                // Conv1 does not accumulate
            mux_data_in    = conv1_data_in;      
            mux_weight_in  = conv1_weight_in;   
            mux_bias_in    = conv1_bias_in;
            mux_shift_val  = 4'd9;
        end else begin
            // Route Conv2 Signals
            mux_compute_en = conv2_compute_en;  
            mux_accumulate = conv2_accumulate;  
            mux_data_in    = conv2_data_in;      
            mux_weight_in  = conv2_weight_in;
            mux_bias_in    = conv2_bias_in;
            mux_shift_val  = 4'd8;
        end
    end

    // Shared NPU Core Instantiation
    logic npu_valid;

    ws_conv_core_gowin #(
        .NUM_CORES(4)
    ) u_npu (
        .clk(clk),
        .rst(rst),
        .compute_en(mux_compute_en),
        .accumulate(mux_accumulate),
        .data_in(mux_data_in),
        .weight_in(mux_weight_in),
        .bias_in(mux_bias_in),
        .shift_val(mux_shift_val), 
        .mac_out(npu_out),
        .valid_out(npu_valid)
    );

    // Output Demultiplexer & Validation Gate
    
    // Conv1 gets the valid signal directly when active
    assign conv1_valid_out = npu_valid & (layer_state == 1'b0);

    // Conv2 gets the valid signal gated by !accumulate to hide partial sums
    assign conv2_valid_out_gated = npu_valid & (layer_state == 1'b1) & !conv2_accumulate;

endmodule
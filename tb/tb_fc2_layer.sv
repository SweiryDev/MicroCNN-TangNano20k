`timescale 1ns/1ps

// Standalone verification of the FC2 datapath using the behavioral
// NPU array model. Compares the raw 32-bit output logits against 
// the Python-generated TAP file. Features exact pipeline bubble masking.

module tb_fc2_layer();

    // Testbench Signals
    logic clk;
    logic rst;
    logic start;
    
    // Clock Generation (27 MHz equivalent)
    initial begin
        clk = 0;
        forever #18.5 clk = ~clk; 
    end

    // Mock FC2 Input RAM (Stores the 32 neurons from FC1)
    logic [7:0]  raw_fc1_output [0:31]; 
    logic [63:0] fc2_input_ram [0:3];   
    logic [1:0]  ram_raddr;
    logic [63:0] fc2_rdata;

    initial begin
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tap_fc1_output.hex", raw_fc1_output);
        
        for (int i = 0; i < 4; i++) begin
            fc2_input_ram[i] = {raw_fc1_output[i*8+7], raw_fc1_output[i*8+6], 
                                raw_fc1_output[i*8+5], raw_fc1_output[i*8+4], 
                                raw_fc1_output[i*8+3], raw_fc1_output[i*8+2], 
                                raw_fc1_output[i*8+1], raw_fc1_output[i*8+0]};
        end
    end
    
    // Synchronous read to perfectly mimic the 1-cycle latency of FPGA Block RAM
    always_ff @(posedge clk) begin
        fc2_rdata <= fc2_input_ram[ram_raddr];
    end

    // DUT Interconnects
    logic [4:0] weight_raddr;
    logic [2:0] bias_raddr;
    logic       param_en;
    
    logic [63:0] fc2_weight_rdata;
    logic [31:0] fc2_bias_rdata;
    
    logic       fc2_mult_ce, fc2_mult_clear;
    logic       fc2_valid_out;
    logic [2:0] current_neuron;
    logic       layer_done;
    logic       npu_data_valid; // NEW: Controls the pipeline bubble

    // FC2 Parameter ROM
    fc2_param_rom u_fc2_params (
        .clk(clk),
        .en(param_en),
        .weight_addr(weight_raddr),
        .bias_addr(bias_raddr),
        .weights_out(fc2_weight_rdata),
        .bias_out(fc2_bias_rdata)
    );

    // FC2 FSM (Timing Wheel Architecture)
    fc2_fsm u_fc2_fsm (
        .clk(clk),
        .rst(rst),
        .start(start),
        .ram_raddr(ram_raddr),
        .weight_raddr(weight_raddr),
        .bias_raddr(bias_raddr),
        .param_en(param_en),
        .mult_ce(fc2_mult_ce),
        .mult_clear(fc2_mult_clear),
        .fc2_valid_out(fc2_valid_out),
        .current_neuron(current_neuron),
        .layer_done(layer_done),
        .npu_data_valid(npu_data_valid) // Masking control
    );

    logic [63:0] masked_fc2_rdata;
    logic [63:0] masked_fc2_weight;
    
    assign masked_fc2_rdata  = npu_data_valid ? fc2_rdata : 64'd0;
    assign masked_fc2_weight = npu_data_valid ? fc2_weight_rdata : 64'd0;

    // Behavioral NPU Array Model (Replaces TDM Router for Simulation)
    logic signed [31:0] psum_lanes_out [0:7];
    logic fc2_mult_ce_d;

    // 1-Cycle RAM Delay Alignment
    always_ff @(posedge clk or posedge rst) begin
        if (rst) fc2_mult_ce_d <= 1'b0;
        else     fc2_mult_ce_d <= fc2_mult_ce;
    end

    fc_npu_array u_fc_npu (
        .clk(clk),
        .ce(fc2_mult_ce_d), 
        .reset(fc2_mult_clear),
        .data_in(masked_fc2_rdata),     // Fed with masked data
        .weights_in(masked_fc2_weight), // Fed with masked weights
        .psum_out(psum_lanes_out)
    );

    // FC2 Reduction Tree (Raw 32-bit Logits)
    logic signed [31:0] fc2_out_32b;

    fc2_reduction_tree u_fc2_reduction (
        .psum_lanes(psum_lanes_out),
        .bias_in(fc2_bias_rdata),
        .fc2_out_32b(fc2_out_32b)
    );

    // -- Automated Validation Logic --
    logic signed [31:0] expected_logits [0:7];
    int error_count = 0;

    initial begin
        // Load the expected 32-bit output logits from the Python model
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tap_fc2_output_logits.hex", expected_logits);
    end

    // Monitor and verify outputs as they become valid
    always_ff @(posedge clk) begin
        if (fc2_valid_out) begin
            if (fc2_out_32b !== expected_logits[current_neuron]) begin
                $display("ERROR at Time %0t | Neuron [%0d]: Expected %h, Got %h", 
                         $time, current_neuron, expected_logits[current_neuron], fc2_out_32b);
                error_count++;
            end else begin
                $display("PASS  at Time %0t | Neuron [%0d]: Logit = %h", 
                         $time, current_neuron, fc2_out_32b);
            end
        end
    end

    // Test Sequence
    initial begin
        $display("=========================================================");
        $display("Starting FC2 Layer Testbench...");
        $display("=========================================================");
        
        rst   = 1;
        start = 0;
        #100;
        
        rst   = 0;
        #50;
        
        // Trigger the FSM
        start = 1;
        #37; 
        start = 0;

        // Wait for the layer to finish
        wait(layer_done == 1'b1);
        #50;

        $display("=========================================================");
        if (error_count == 0) begin
            $display("TEST PASSED! All 8 output logits match the TAP file.");
        end else begin
            $display("TEST FAILED with %0d errors.", error_count);
        end
        $display("=========================================================");
        
        $stop;
    end

endmodule
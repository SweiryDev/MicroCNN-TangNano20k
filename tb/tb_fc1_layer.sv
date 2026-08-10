`timescale 1ns/1ps

module tb_fc1_layer();

    // Clock and Reset Generation
    logic clk;
    logic rst;
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz simulation clock
    end

    // Signals
    logic start;
    logic layer_done;
    
    // Memory interfaces
    logic [5:0]  ram_raddr;
    logic [10:0] weight_raddr;
    logic [4:0]  bias_raddr;
    logic        param_en;
    
    logic [63:0] ram_rdata;
    logic [63:0] weight_rdata;
    logic [31:0] bias_rdata;
    
    // NPU Control
    logic mult_ce;
    logic mult_ce_d; // 1-cycle delayed enable to align with RAM latency
    logic mult_clear;
    logic signed [31:0] psum_lanes [0:7];
    
    // Reduction Tree & Output
    logic       fc1_valid_out;
    logic [4:0] current_neuron;
    logic [7:0] fc2_wdata;

    // -- TAP File Verification Setup --
    logic [7:0] expected_outputs [0:31];
    integer error_count = 0;

    // -- Simulated Memory Blocks --
    logic [63:0] sim_input_ram [0:49];
    
    fc1_param_rom u_params (
        .clk(clk),
        .en(param_en),
        .weight_addr(weight_raddr),
        .bias_addr(bias_raddr),
        .weights_out(weight_rdata),
        .bias_out(bias_rdata)
    );

    initial begin
        // Load the 50x64b input test image 
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/fc1_input_64b.hex", sim_input_ram);
        // Load the expected output values
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tap_fc1_output.hex", expected_outputs);
    end

    // Simulated RAM read with 1-cycle latency
    always_ff @(posedge clk) begin
        if (param_en) begin
            ram_rdata <= sim_input_ram[ram_raddr];
        end
    end

    // Fix for the 'xx' bug: Delay mult_ce by 1 clock cycle to match RAM read latency
    always_ff @(posedge clk or posedge rst) begin
        if (rst) mult_ce_d <= 1'b0;
        else     mult_ce_d <= mult_ce;
    end

    // -- DUT Instantiations --
    
    fc1_fsm u_fsm (
        .clk(clk),
        .rst(rst),
        .start(start),
        .fc1_ram_raddr(ram_raddr),
        .fc1_weight_raddr(weight_raddr),
        .fc1_bias_raddr(bias_raddr),
        .param_en(param_en),
        .mult_ce(mult_ce),
        .mult_clear(mult_clear),
        .fc1_valid_out(fc1_valid_out),
        .current_neuron(current_neuron),
        .layer_done(layer_done)
    );

    fc_npu_array u_npu (
        .clk(clk),
        .ce(mult_ce_d), // Feed the DELAYED enable to the NPU
        .reset(mult_clear),
        .data_in(ram_rdata),
        .weights_in(weight_rdata),
        .psum_out(psum_lanes)
    );

    fc1_reduction_tree u_reduction (
        .psum_lanes(psum_lanes),
        .bias_in(bias_rdata),
        .fc2_wdata(fc2_wdata)
    );

    // -- Test Stimulus & Verification Logger --
    initial begin
        start = 0;
        rst = 1;
        #20;
        
        rst = 0;
        #10;
        start = 1;
        #10;
        start = 0;
        
        wait (layer_done == 1'b1);
        
        #50;
        $display("========================================");
        $display("FC1 SIMULATION COMPLETE");
        $display("Total Errors: %0d", error_count);
        $display("========================================");
        $stop;
    end

    // Automated Verification Logger
    always_ff @(posedge clk) begin
        if (fc1_valid_out) begin
            if (fc2_wdata !== expected_outputs[current_neuron]) begin
                $display("Time: %0t | ERROR | Neuron [%0d] | Expected: %h, Got: %h", 
                         $time, current_neuron, expected_outputs[current_neuron], fc2_wdata);
                error_count++;
            end else begin
                $display("Time: %0t | PASS  | Neuron [%0d] | Output: %h", 
                         $time, current_neuron, fc2_wdata);
            end
        end
    end

endmodule
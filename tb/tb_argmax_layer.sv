`timescale 1ns/1ps

module tb_argmax_layer();

    // System signals
    logic clk;
    logic rst;

    // UUT Inputs
    logic        fc2_start;
    logic        fc2_valid_in;
    logic [2:0]  current_neuron;
    logic signed [31:0] data_in;

    // UUT Outputs
    logic [2:0]  predicted_class;
    logic        argmax_done;

    // Memory array to hold the 32-bit hex file data
    // Sized for 8 elements to match the [2:0] index
    logic signed [31:0] fc2_logits [0:7]; 

    // Instantiate the Argmax Module
    argmax_layer uut (
        .clk(clk),
        .rst(rst),
        .fc2_start(fc2_start),
        .fc2_valid_in(fc2_valid_in),
        .current_neuron(current_neuron),
        .data_in(data_in),
        .predicted_class(predicted_class),
        .argmax_done(argmax_done)
    );

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus and Verification
    integer i;
    
    initial begin
        // Initialize Default States
        rst = 1'b1;
        fc2_start = 1'b0;
        fc2_valid_in = 1'b0;
        current_neuron = 3'd0;
        data_in = 32'd0;

        // Load the hex file into the memory array
        $readmemh("hardware_sim_vectors/tap_fc2_output_logits.hex", fc2_logits);

        // Release Reset
        #20;
        rst = 1'b0;
        #10;

        // Pulse the Start Signal
        @(posedge clk);
        fc2_start = 1'b1;
        @(posedge clk);
        fc2_start = 1'b0;

        // Feed the Logits Sequentially (0 to 7)
        for (i = 0; i < 8; i = i + 1) begin
            fc2_valid_in = 1'b1;
            current_neuron = i[2:0];
            data_in = fc2_logits[i];
            @(posedge clk);
        end

        // Conclude Feeding
        fc2_valid_in = 1'b0;

        // Wait a few cycles to allow outputs to settle
        #20;

        // Report the Results
        if (argmax_done) begin
            $display("----------------------------------------");
            $display("SUCCESS: argmax_done flag was asserted.");
            $display("Predicted Class: %0d", predicted_class);
            $display("----------------------------------------");
        end else begin
            $display("ERROR: argmax_done was not asserted at the end of the sequence.");
        end

        #10;
        $finish;
    end

endmodule
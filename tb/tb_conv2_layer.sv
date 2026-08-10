`timescale 1ns/1ps

// Validate the Conv2 math and MaxPool2 cascade. 
// FSM has been rewritten to CHW dataflow, natively matching the 
// MaxPool module and the verification taps without tracking logic.

module tb_conv2_layer;

    logic clk = 0;
    logic rst;
    logic start;
    
    always #10 clk = ~clk; // 50 MHz simulation clock

    // -- Memory Declarations & Loading --
    logic [7:0] pool1_mem [0:1351];         
    logic [7:0] golden_conv2_mem [0:1935];  
    logic [7:0] golden_pool2_mem [0:399];   
    
    initial begin
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tap_maxpool1_output.hex", pool1_mem);
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tap_conv2_output.hex", golden_conv2_mem);
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tap_maxpool2_output.hex", golden_pool2_mem);
    end

    // LAYER 2: Control FSM (Runs 1 cycle ahead of Datapath)
    logic [7:0] ram_raddr;
    logic       shift_en, chunk_sel, accumulate, compute_en;
    logic [3:0] filter_idx;
    logic       layer_done, channel_done;

    conv2_fsm u_fsm (
        .clk(clk), .rst(rst), .start(start),
        .ram_raddr(ram_raddr), .shift_en(shift_en),
        .filter_idx(filter_idx), .chunk_sel(chunk_sel),
        .accumulate(accumulate), .compute_en(compute_en),
        .layer_done(layer_done),
        .channel_done(channel_done)
    );

    logic [7:0] ram_raddr_d;
    logic       shift_en_d, chunk_sel_d, accumulate_d, compute_en_d, channel_done_d;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ram_raddr_d    <= 8'd0;
            shift_en_d     <= 1'b0;
            chunk_sel_d    <= 1'b0;
            accumulate_d   <= 1'b0;
            compute_en_d   <= 1'b0;
            channel_done_d <= 1'b0; 
        end else begin
            ram_raddr_d    <= ram_raddr;
            shift_en_d     <= shift_en;
            chunk_sel_d    <= chunk_sel;
            accumulate_d   <= accumulate;
            compute_en_d   <= compute_en;
            channel_done_d <= channel_done; 
        end
    end

    logic [7:0] ram_rdata [0:7];
    
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            ram_rdata[i] = pool1_mem[(i * 169) + ram_raddr_d];
        end
    end

    // LAYER 2: Datapath
    logic [7:0] lb_window_out [0:3][0:2][0:2];
    
    conv2_line_buffer_wrapper u_lb_wrapper (
        .clk(clk), .rst(rst), 
        .shift_en(shift_en_d), 
        .chunk_sel(chunk_sel_d), 
        .ram_data_in(ram_rdata),
        .muxed_window_out(lb_window_out)
    );

    logic [7:0]  npu_weights [0:3][0:2][0:2];
    logic [31:0] npu_bias;
    
    conv2_param_rom u_params (
        .clk(clk), 
        .weight_en(1'b1),        
        .bias_en(1'b1),          
        .filter_idx(filter_idx), // Look-ahead fetch
        .chunk_sel(chunk_sel_d), 
        .npu_weights(npu_weights), 
        .bias_out(npu_bias)
    );

    logic [7:0] npu_out;
    logic       npu_valid;
    
    ws_conv_core #(.NUM_CORES(4)) u_npu (
        .clk(clk), .rst(rst), 
        .compute_en(compute_en_d), 
        .accumulate(accumulate_d), 
        .data_in(lb_window_out), .weight_in(npu_weights),
        .bias_in(npu_bias), .shift_val(4'd8),
        .mac_out(npu_out), .valid_out(npu_valid)
    );

    // External Validation Gate for MaxPool Cascade
    logic gated_npu_valid;
    assign gated_npu_valid = npu_valid & !accumulate_d;

    logic [7:0] pool2_out;
    logic       pool2_valid;

    maxpool2x2 #(.IN_WIDTH(11), .OUT_WIDTH(5)) u_maxpool2 (
        .clk(clk), 
        .rst(rst | channel_done_d), 
        .valid_in(gated_npu_valid), 
        .data_in(npu_out),
        .valid_out(pool2_valid), 
        .max_out(pool2_out)
    );

    // Verification & Test Execution
    int conv2_count = 0, conv2_err = 0;
    int pool2_count = 0, pool2_err = 0;
    
    always_ff @(posedge clk) begin
        // Conv2 Verification (Simple 1D indexing because of CHW streaming)
        if (gated_npu_valid) begin
            if (npu_out !== golden_conv2_mem[conv2_count]) begin
                $display("CONV2 ERR @ Px %0d | HW = %h, EXP = %h", 
                         conv2_count, npu_out, golden_conv2_mem[conv2_count]);
                conv2_err++;
            end
            conv2_count++;
        end

        // MaxPool2 Verification (Simple 1D indexing because of CHW streaming)
        if (pool2_valid) begin
            if (pool2_out !== golden_pool2_mem[pool2_count]) begin
                $display("POOL2 ERR @ Px %0d | HW = %h, EXP = %h", 
                         pool2_count, pool2_out, golden_pool2_mem[pool2_count]);
                pool2_err++;
            end
            pool2_count++;
        end
    end

    initial begin
        $display("Starting CHW Conv2 + MaxPool2 Validation...");
        rst = 1;
        start = 0;
        
        #50;
        rst = 0;
        #20;
        
        start = 1;
        #20;
        start = 0;

        wait(layer_done == 1);
        #200; 

        $display("-----------------------------------------");
        $display("Conv2D Pixels Checked: %0d / 1936 | Errors: %0d", conv2_count, conv2_err);
        $display("MaxPool Pixels Checked: %0d / 400 | Errors: %0d", pool2_count, pool2_err);
        
        if (conv2_err == 0 && pool2_err == 0 && conv2_count == 1936 && pool2_count == 400) begin
            $display("RESULT: PASS [BIT-ACCURATE]");
        end else begin
            $display("RESULT: FAIL");
        end
        $display("-----------------------------------------");
        
        $stop;
    end

endmodule
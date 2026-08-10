`timescale 1ns/1ps

module tb_conv1_layer;

    logic clk = 0;
    logic rst;
    logic start;
    
    always #10 clk = ~clk; // 50 MHz clock

    // FSM Wires
    logic [9:0] img_addr;
    logic       img_en;
    logic [2:0] filter_idx;
    logic       weight_en;
    logic       bias_en;
    logic       shift_en;
    logic       compute_en;
    logic       layer_done;

    // Simulated BRAM Memories (Only the input image and verification taps remain)
    logic [7:0]  image_mem_8bit  [0:2351]; 
    logic [7:0]  golden_conv_mem [0:5407]; // 26x26 * 8 = 5408 bytes
    logic [7:0]  golden_pool_mem [0:1351]; // 13x13 * 8 = 1352 bytes

    logic [31:0] img_read_data;

    initial begin
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tb_input_image.hex", image_mem_8bit);
        
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tap_conv1_output.hex", golden_conv_mem);
        $readmemh("/home/ubuair/Desktop/Gowin_IDE/NPU/hardware_sim_vectors/tap_maxpool1_output.hex", golden_pool_mem);
    end

    // BRAM Simulation (Memory Packing for Input Image Only)
    always_ff @(posedge clk) begin
        if (img_en) begin
            img_read_data[7:0]   <= image_mem_8bit[img_addr * 3 + 0]; // R
            img_read_data[15:8]  <= image_mem_8bit[img_addr * 3 + 1]; // G
            img_read_data[23:16] <= image_mem_8bit[img_addr * 3 + 2]; // B
            img_read_data[31:24] <= 8'd0;                             // Pad
        end
    end

    // Datapath Routing for Line Buffer
    logic [7:0] lb_data_in [0:3];
    assign lb_data_in[0] = img_read_data[7:0];   
    assign lb_data_in[1] = img_read_data[15:8];  
    assign lb_data_in[2] = img_read_data[23:16]; 
    assign lb_data_in[3] = img_read_data[31:24]; 

    // Valid Window Tracking (Prevents Line Buffer Wrap-Around)
    logic [9:0] current_pixel_idx;
    
    always_ff @(posedge clk) begin
        if (img_en) current_pixel_idx <= img_addr;
    end

    logic [4:0] lb_row, lb_col;
    logic       window_valid_combo, window_valid_synced;

    assign lb_row = current_pixel_idx / 28;
    assign lb_col = current_pixel_idx % 28;
    assign window_valid_combo = shift_en && (lb_row >= 2) && (lb_col >= 2);

    // 1-Cycle Delay to perfectly align with line buffer's internal register
    always_ff @(posedge clk or posedge rst) begin
        if (rst) window_valid_synced <= 1'b0;
        else     window_valid_synced <= window_valid_combo;
    end

    // -- Hardware Modules --
    conv1_fsm u_fsm (
        .clk(clk),
        .rst(rst),
        .start(start),
        .img_addr(img_addr),
        .img_en(img_en),
        .filter_idx(filter_idx),
        .weight_en(weight_en),
        .bias_en(bias_en),
        .shift_en(shift_en),
        .compute_en(compute_en),
        .layer_done(layer_done)
    );

    logic [7:0] lb_window_out [0:3][0:2][0:2];
    
    unified_line_buffer #(
        .NUM_CHANNELS(4),
        .IMAGE_WIDTH(28)
    ) u_line_buffer (
        .clk(clk),
        .rst(rst),
        .shift_en(shift_en),
        .data_in(lb_data_in),
        .window_out(lb_window_out)
    );

    // --- INSTANTIATE THE CONV1 PARAM ROM ---
    logic [7:0]  npu_weights [0:3][0:2][0:2];
    logic [31:0] npu_bias;

    conv1_param_rom u_conv1_params (
        .clk(clk),
        .weight_en(weight_en),
        .bias_en(bias_en),
        .filter_idx(filter_idx),
        .npu_weights(npu_weights),
        .bias_out(npu_bias)
    );

    logic [7:0] npu_out;
    logic       npu_valid;
    
    ws_conv_core #(
        .NUM_CORES(4)
    ) u_npu (
        .clk(clk),
        .rst(rst),
        .compute_en(window_valid_synced), 
        .accumulate(1'b0),
        .data_in(lb_window_out),
        .weight_in(npu_weights),
        .bias_in(npu_bias),          // Now driven directly by the ROM
        .shift_val(4'd9), 
        .mac_out(npu_out),
        .valid_out(npu_valid)
    );

    logic pool_valid;
    logic [7:0] pool_out;

    maxpool2x2 #(
        .IN_WIDTH(26),
        .OUT_WIDTH(13)
    ) u_maxpool (
        .clk(clk),
        .rst(rst),
        .valid_in(npu_valid),
        .data_in(npu_out),
        .valid_out(pool_valid),
        .max_out(pool_out)
    );

    // -- Verification Logic --
    int conv_count = 0, conv_err = 0;
    int pool_count = 0, pool_err = 0;
    
    int hw_filter, hw_row, hw_col, flat_index;

    always_ff @(posedge clk) begin
        // Verify NPU (Pre-Maxpool)
        if (npu_valid) begin
            if (npu_out !== golden_conv_mem[conv_count]) begin
                $display("CONV ERR @ F:%0d, R:%0d, C:%0d | HW = %h, EXP = %h", 
                         hw_filter, hw_row, hw_col, npu_out, golden_conv_mem[flat_index]);
                conv_err++;
            end
            conv_count++;
        end
        
        // Verify MaxPool (Post-Maxpool)
        if (pool_valid) begin
            if (pool_out !== golden_pool_mem[pool_count]) begin
                $display("POOL ERR @ F:%0d, R:%0d, C:%0d | HW = %h, EXP = %h", 
                         hw_filter, hw_row, hw_col, pool_out, golden_pool_mem[flat_index]);
                pool_err++;
            end
            pool_count++;
        end
    end

    // Main Test
    initial begin
        $display("Starting Clean Layer 1 Simulation...");
        rst = 1;
        start = 0;
        
        #50;
        rst = 0;
        #20;
        
        start = 1;
        #20;
        start = 0;

        wait(layer_done == 1);
        #50;

        $display("-----------------------------------------");
        $display("Simulation Complete.");
        $display("Conv2D Pixels Checked: %0d / 5408 | Errors: %0d", conv_count, conv_err);
        $display("MaxPool Pixels Checked: %0d / 1352 | Errors: %0d", pool_count, pool_err);
        
        if (conv_err == 0 && pool_err == 0 && pool_count == 1352) begin
            $display("RESULT: PASS [BIT-ACCURATE]");
        end else begin
            $display("RESULT: FAIL");
        end
        $display("-----------------------------------------");
        
        $stop;
    end

endmodule
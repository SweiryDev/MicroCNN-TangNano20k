`timescale 1ns/1ps

// Complete datapath integration (Conv1 -> Conv2 -> FC1 -> FC2 -> Argmax).

module npu_top (
    input  logic        system_clk, // continuous clock
    input  logic        npu_clk,    // gated clock
    input  logic        rst,        
    
    // -- Image RAM Interface --
    output logic [9:0]  img_addr,
    output logic        img_en,
    input  logic [23:0] img_rdata,  // {R, G, B}
    
    output logic [2:0]  class_idx,
    output logic        npu_sleep,   // sleep signal to the clock gate
    output logic        npu_done
);

    // -- MASTER CONTROL PLANE --
    logic conv1_layer_done, conv2_layer_done, fc1_layer_done, fc2_layer_done;
    logic conv1_start, conv2_start, fc1_start, fc2_start;
    logic layer_state, system_done;

    master_pipeline_fsm u_master_fsm (
        .clk(system_clk), // Only the Master FSM connected to continuous clock
        .rst(rst),
        .conv1_layer_done(conv1_layer_done),
        .conv2_layer_done(conv2_layer_done),
        .fc1_layer_done(fc1_layer_done),
        .fc2_layer_done(fc2_layer_done),
        .conv1_start(conv1_start),
        .conv2_start(conv2_start),
        .fc1_start(fc1_start),
        .fc2_start(fc2_start),
        .layer_state(layer_state),
        .system_done(system_done),
        .npu_sleep(npu_sleep)
    );

    // FC Layer State tracker for the FC TDM Router
    logic fc_layer_state;
    always_ff @(posedge npu_clk or posedge rst) begin
        if (rst) begin
            fc_layer_state <= 1'b0; // 0 = FC1 Active
        end else if (fc1_start) begin
            fc_layer_state <= 1'b0;
        end else if (fc2_start) begin
            fc_layer_state <= 1'b1; // 1 = FC2 Active
        end
    end

    // -- CONV1 DATAPATH --
    logic       conv1_shift_en, conv1_weight_en, conv1_bias_en, conv1_compute_en_raw;
    logic [2:0] conv1_filter_idx;

    conv1_fsm u_conv1_fsm (
        .clk(npu_clk), .rst(rst), .start(conv1_start),
        .img_addr(img_addr), .img_en(img_en), .filter_idx(conv1_filter_idx),
        .weight_en(conv1_weight_en), .bias_en(conv1_bias_en),
        .shift_en(conv1_shift_en), .compute_en(conv1_compute_en_raw),
        .layer_done(conv1_layer_done)
    );

    // Split the 24-bit RAM output back into the 3 channels for the NPU
    logic [7:0] img_r_data, img_g_data, img_b_data;
    assign img_r_data = img_rdata[23:16];
    assign img_g_data = img_rdata[15:8];
    assign img_b_data = img_rdata[7:0];

    logic [7:0] lb1_data_in [0:3];
    assign lb1_data_in[0] = img_r_data;
    assign lb1_data_in[1] = img_g_data;
    assign lb1_data_in[2] = img_b_data;
    assign lb1_data_in[3] = 8'd0;

    logic [7:0]  conv1_npu_weights [0:3][0:2][0:2];
    logic [31:0] conv1_bias_read_data;
    conv1_param_rom u_conv1_params (
        .clk(npu_clk), .weight_en(conv1_weight_en), .bias_en(conv1_bias_en),
        .filter_idx(conv1_filter_idx), .npu_weights(conv1_npu_weights), .bias_out(conv1_bias_read_data)
    );
    
    logic [9:0] current_pixel_idx;
    logic [9:0] lb1_row, lb1_col;
    logic       window1_valid_combo, window1_valid_synced;
    
    always_ff @(posedge npu_clk) begin
        if (img_en) current_pixel_idx <= img_addr;
    end
    
    assign lb1_row = current_pixel_idx / 28;
    assign lb1_col = current_pixel_idx % 28;
    assign window1_valid_combo = conv1_shift_en && (lb1_row >= 2) && (lb1_col >= 2);

    always_ff @(posedge npu_clk or posedge rst) begin
        if (rst) window1_valid_synced <= 1'b0;
        else     window1_valid_synced <= window1_valid_combo;
    end

    logic [7:0] lb1_window_out [0:3][0:2][0:2];
    unified_line_buffer #(.NUM_CHANNELS(4), .IMAGE_WIDTH(28)) u_lb1 (
        .clk(npu_clk), .rst(rst), .shift_en(conv1_shift_en),
        .data_in(lb1_data_in), .window_out(lb1_window_out)
    );

    // -- CONV2 DATAPATH --
    logic [7:0] conv2_ram_raddr;
    logic       conv2_shift_en, conv2_chunk_sel, conv2_accumulate, conv2_compute_en, conv2_channel_done;
    logic [3:0] conv2_filter_idx;

    conv2_fsm u_conv2_fsm (
        .clk(npu_clk), .rst(rst), .start(conv2_start),
        .ram_raddr(conv2_ram_raddr), .shift_en(conv2_shift_en),
        .filter_idx(conv2_filter_idx), .chunk_sel(conv2_chunk_sel),
        .accumulate(conv2_accumulate), .compute_en(conv2_compute_en),
        .layer_done(conv2_layer_done), .channel_done(conv2_channel_done)
    );

    logic conv2_shift_en_d, conv2_chunk_sel_d, conv2_accumulate_d, conv2_compute_en_d, conv2_channel_done_d;
    always_ff @(posedge npu_clk or posedge rst) begin
        if (rst) begin
            conv2_shift_en_d     <= 1'b0;
            conv2_chunk_sel_d    <= 1'b0;
            conv2_accumulate_d   <= 1'b0;
            conv2_compute_en_d   <= 1'b0;
            conv2_channel_done_d <= 1'b0;
        end else begin
            conv2_shift_en_d     <= conv2_shift_en;
            conv2_chunk_sel_d    <= conv2_chunk_sel;
            conv2_accumulate_d   <= conv2_accumulate;
            conv2_compute_en_d   <= conv2_compute_en;
            conv2_channel_done_d <= conv2_channel_done;
        end
    end

    logic [7:0] ram_rdata [0:7];
    logic [7:0] lb2_window_out [0:3][0:2][0:2];
    
    conv2_line_buffer_wrapper u_lb2 (
        .clk(npu_clk), .rst(rst), 
        .shift_en(conv2_shift_en_d), .chunk_sel(conv2_chunk_sel_d), 
        .ram_data_in(ram_rdata), .muxed_window_out(lb2_window_out)
    );

    logic [7:0]  conv2_npu_weights [0:3][0:2][0:2];
    logic [31:0] conv2_bias_read_data;
    conv2_param_rom u_conv2_params (
        .clk(npu_clk), .weight_en(1'b1), .bias_en(1'b1), 
        .filter_idx(conv2_filter_idx), .chunk_sel(conv2_chunk_sel_d),
        .npu_weights(conv2_npu_weights), .bias_out(conv2_bias_read_data)
    );

    // -- CONV TDM ROUTER and MAXPOOL 1 --
    logic [7:0] npu_out;
    logic       conv1_npu_valid, conv2_npu_valid_gated;

    tdm_npu_router u_tdm_router (
        .clk(npu_clk), .rst(rst), .layer_state(layer_state),
        .conv1_compute_en(window1_valid_synced),
        .conv1_data_in(lb1_window_out), .conv1_weight_in(conv1_npu_weights), .conv1_bias_in(conv1_bias_read_data),
        .conv2_compute_en(conv2_compute_en_d),
        .conv2_accumulate(conv2_accumulate_d),
        .conv2_data_in(lb2_window_out), .conv2_weight_in(conv2_npu_weights), .conv2_bias_in(conv2_bias_read_data),
        .npu_out(npu_out),
        .conv1_valid_out(conv1_npu_valid), .conv2_valid_out_gated(conv2_npu_valid_gated)
    );

    logic pool1_valid;
    logic [7:0] pool1_out;
    maxpool2x2 #(.IN_WIDTH(26), .OUT_WIDTH(13)) u_maxpool1 (
        .clk(npu_clk), .rst(rst), .valid_in(conv1_npu_valid), 
        .data_in(npu_out), .valid_out(pool1_valid), .max_out(pool1_out)
    );

    logic [7:0] ram_we, ram_waddr, ram_wdata;
    conv1_to_conv2_router u_router (
        .clk(npu_clk), .rst(rst), .pool_valid(pool1_valid), .pool_data(pool1_out),
        .ram_we(ram_we), .ram_waddr(ram_waddr), .ram_wdata(ram_wdata)
    );

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : conv2_ram_banks
            conv2_input_ram u_ram (
                .clka(npu_clk), .cea(ram_we[i]), .reseta(rst), .ada(ram_waddr), .din(ram_wdata),
                .clkb(npu_clk), .ceb(1'b1), .oce(1'b1), .resetb(rst),
                .adb(conv2_ram_raddr), .dout(ram_rdata[i])
            );
        end
    endgenerate

    // -- MAXPOOL 2 and FC1 INPUT BUFFER --
    logic pool2_valid;
    logic [7:0] pool2_out;
    maxpool2x2 #(.IN_WIDTH(11), .OUT_WIDTH(5)) u_maxpool2 (
        .clk(npu_clk), .rst(rst | conv2_channel_done_d), 
        .valid_in(conv2_npu_valid_gated), 
        .data_in(npu_out), .valid_out(pool2_valid), .max_out(pool2_out)
    );

    logic [63:0] fc1_rdata; 
    logic [5:0]  fc1_raddr; 

    fc1_buffer_ram u_fc1_ram (
        .clk(npu_clk), .rst(rst), .we(pool2_valid),
        .wdata(pool2_out), .raddr(fc1_raddr), .rdata(fc1_rdata)
    );

    // -- FC DATAPATH PREPARATION and SHARED ROUTING --
    logic [10:0] fc1_weight_raddr;
    logic [4:0]  fc1_bias_raddr;
    logic        fc1_param_en;
    logic [63:0] fc1_weight_rdata;
    logic [31:0] fc1_bias_rdata;
    logic        fc1_mult_ce, fc1_mult_clear;
    logic        fc1_valid_out;
    logic [4:0]  fc1_current_neuron;
    logic [7:0]  fc2_wdata;
    
    logic [4:0]  fc2_weight_raddr;
    logic [2:0]  fc2_bias_raddr;
    logic        fc2_param_en;
    logic [63:0] fc2_weight_rdata;
    logic [31:0] fc2_bias_rdata;
    logic        fc2_mult_ce, fc2_mult_clear;
    logic        fc2_valid_out;
    logic [2:0]  fc2_current_neuron;
 
    logic [1:0]  fc2_raddr;
    logic [63:0] fc2_ram_rdata;

    logic signed [31:0] shared_fc_psum_lanes [0:7];
    logic fc2_param_en_d;

    always_ff @(posedge npu_clk or posedge rst) begin
        if (rst) fc2_param_en_d <= 1'b0;
        else     fc2_param_en_d <= fc2_param_en;
    end

    tdm_fc_router u_tdm_fc_router (
        .clk(npu_clk),
        .rst(rst),
        .fc_layer_state(fc_layer_state),
        
        .fc1_mult_ce(fc1_mult_ce),
        .fc1_mult_clear(fc1_mult_clear),
        .fc1_rdata(fc1_rdata),
        .fc1_weight_rdata(fc1_weight_rdata),
        
        .fc2_mult_ce(fc2_mult_ce),
        .fc2_mult_clear(fc2_mult_clear),
        .fc2_rdata(fc2_param_en_d ? fc2_ram_rdata : 64'd0),
        .fc2_weight_rdata(fc2_param_en_d ? fc2_weight_rdata : 64'd0),
        
        .psum_lanes_out(shared_fc_psum_lanes)
    );

    // -- FC1 DATAPATH and CONTROL --
    fc1_param_rom u_fc1_params (
        .clk(npu_clk), .en(fc1_param_en),
        .weight_addr(fc1_weight_raddr), .bias_addr(fc1_bias_raddr),
        .weights_out(fc1_weight_rdata), .bias_out(fc1_bias_rdata)
    );

    fc1_fsm u_fc1_fsm (
        .clk(npu_clk), .rst(rst), .start(fc1_start),
        .fc1_ram_raddr(fc1_raddr), 
        .fc1_weight_raddr(fc1_weight_raddr), .fc1_bias_raddr(fc1_bias_raddr),
        .param_en(fc1_param_en), .mult_ce(fc1_mult_ce), .mult_clear(fc1_mult_clear),
        .fc1_valid_out(fc1_valid_out), .current_neuron(fc1_current_neuron),
        .layer_done(fc1_layer_done)
    );

    fc1_reduction_tree u_fc1_reduction (
        .psum_lanes(shared_fc_psum_lanes), 
        .bias_in(fc1_bias_rdata),
        .fc2_wdata(fc2_wdata)
    );

    // -- FC2 BUFFER RAM --
    fc2_buffer_ram u_fc2_ram (
        .clk(npu_clk),
        .rst(rst),
        .we(fc1_valid_out),
        .waddr(fc1_current_neuron), 
        .wdata(fc2_wdata),          
        .raddr(fc2_raddr),   
        .rdata(fc2_ram_rdata)         
    );

    // -- FC2 DATAPATH and ARGMAX LAYER --
    logic signed [31:0] fc2_sum;
    logic [2:0]  predicted_class;

    fc2_param_rom u_fc2_params (
        .clk(npu_clk),
        .en(fc2_param_en),
        .weight_addr(fc2_weight_raddr),
        .bias_addr(fc2_bias_raddr),
        .weights_out(fc2_weight_rdata),
        .bias_out(fc2_bias_rdata)
    );

    fc2_fsm u_fc2_fsm (
        .clk(npu_clk),
        .rst(rst),
        .start(fc2_start),
        .fc2_ram_raddr(fc2_raddr),
        .weight_raddr(fc2_weight_raddr),
        .bias_raddr(fc2_bias_raddr),
        .param_en(fc2_param_en),
        .mult_ce(fc2_mult_ce),
        .mult_clear(fc2_mult_clear),
        .fc2_valid_out(fc2_valid_out),
        .current_neuron(fc2_current_neuron),
        .layer_done() 
    );

    fc2_reduction_tree u_fc2_reduction (
        .psum_lanes(shared_fc_psum_lanes),
        .bias_in(fc2_bias_rdata),
        .fc2_out_32b(fc2_sum)
    );

    argmax_layer u_argmax (
        .clk(npu_clk),
        .rst(rst),
        .fc2_start(fc2_start),
        .fc2_valid_in(fc2_valid_out),
        .current_neuron(fc2_current_neuron),
        .data_in(fc2_sum),
        .predicted_class(predicted_class),
        .argmax_done(fc2_layer_done)
    );

    // class_idx
    always_comb begin
        if (system_done) begin
            class_idx = predicted_class; 
        end else begin
            class_idx = {conv1_start, conv2_start, fc1_start};
        end
    end

    assign npu_done = system_done;

endmodule
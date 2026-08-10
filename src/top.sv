`timescale 1ns/1ps

module top (
    input  logic       clk,    
    input  logic       rst,    
    output logic [5:0] led,    
    input  logic       rx_in,
    output logic       tx_out
);

    logic system_clk;
    logic npu_clk;
    logic npu_sleep;
    logic npu_done;
    logic [2:0] class_result;

    Gowin_rPLL u_pll (
        .clkout(system_clk),
        .clkin(clk)
    );

    // Force the clock to run if the software reset is active, so flip-flops can flush.
    logic actual_npu_sleep;
    assign actual_npu_sleep = npu_sleep & ~npu_software_rst;

    Gowin_DCS u_cg (
        .clkout(npu_clk),
        .clksel({3'b000, ~actual_npu_sleep}), 
        .clk0(system_clk),                   
        .clk1(1'b0),                   
        .clk2(1'b0),                   
        .clk3(1'b0)                    
    );

    logic [7:0] rx_data;
    logic       rx_valid;

    uart_rx u_uart_rx (
        .clk(system_clk),
        .rst(rst),
        .rx_in(rx_in),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    logic        img_we;
    logic [9:0]  img_waddr;
    logic [23:0] img_wdata;
    logic        npu_software_rst;

    soc_controller u_soc_ctrl (
        .clk(system_clk),
        .rst(rst),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .img_we(img_we),
        .img_waddr(img_waddr),
        .img_wdata(img_wdata),
        .npu_rst_out(npu_software_rst)
    );

    logic [9:0]  img_raddr;
    logic        img_ren;
    logic [23:0] img_rdata;

    img_ram u_img_ram (
        .wr_clk(system_clk),
        .we(img_we),
        .waddr(img_waddr),
        .wdata(img_wdata),
        .rd_clk(npu_clk),
        .re(img_ren),
        .raddr(img_raddr),
        .rdata(img_rdata)
    );

    npu_top u_npu (
        .system_clk(system_clk),
        .npu_clk(npu_clk),
        .rst(npu_software_rst),  
        .img_addr(img_raddr),
        .img_en(img_ren),
        .img_rdata(img_rdata),
        .class_idx(class_result),
        .npu_sleep(npu_sleep),
        .npu_done(npu_done)
    );

    assign led = ~{2'b00, class_result};

    logic tx_start;
    logic [7:0] tx_data;
    logic tx_busy;
    logic class_sent;

    uart_tx u_uart_tx (
        .clk(system_clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_out(tx_out),
        .tx_busy(tx_busy)
    );

    always_ff @(posedge system_clk or posedge rst) begin 
        if(rst) begin
            tx_start   <= 1'b0;
            tx_data    <= 8'd0;
            class_sent <= 1'b0;
        end else begin
            tx_start <= 1'b0; 
            
            // Clear the flag when the NPU starts a new inference
            if (!npu_done) begin
                class_sent <= 1'b0;
            end 
            else if(!class_sent & npu_done) begin
                tx_start   <= 1'b1;
                tx_data    <= {5'b00000, class_result} + 8'h30;
                class_sent <= 1'b1; 
            end
        end
    end
endmodule
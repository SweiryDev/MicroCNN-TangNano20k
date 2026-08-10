`timescale 1ns/1ps

// Routes the continuous 1352-pixel maxpool stream into 
// 8 separate channel RAMs (169 pixels per RAM).

module conv1_to_conv2_router (
    input logic clk,
    input logic rst,
    
    // Interface from MaxPool
    input logic pool_valid,
    input logic [7:0] pool_data,

    // Interface to the 8 Conv2 Input RAMs
    output logic [7:0] ram_we,      // 1-hot write enable bus (1 bit per RAM)
    output logic [7:0] ram_waddr,   // Write address (0 to 168)
    output logic [7:0] ram_wdata    // Pixel data to write
);

    logic [7:0] pixel_cnt; // Counts spatial pixels: 0 to 168
    logic [2:0] ch_cnt;    // Counts channels: 0 to 7

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_cnt <= 8'd0;
            ch_cnt    <= 3'd0;
        end else if (pool_valid) begin
            if (pixel_cnt == 8'd168) begin
                pixel_cnt <= 8'd0;          // reset pixel count for the new channel
                ch_cnt    <= ch_cnt + 1'b1; // move to the next channel RAM
            end else begin
                pixel_cnt <= pixel_cnt + 1'b1;
            end
        end
    end

    // 1-Hot Decoder for Write Enables
    // Only the RAM matching ch_cnt gets the write enable pulse
    always_comb begin
        ram_we = 8'd0; // default, all write enables low
        if (pool_valid) begin
            ram_we[ch_cnt] = 1'b1;
        end
    end

    // The address and data are broadcast to all RAMs, 
    // but only the RAM with the active we accept it.
    assign ram_waddr = pixel_cnt;
    assign ram_wdata = pool_data;

endmodule
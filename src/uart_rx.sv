`timescale 1ns/1ps

module uart_rx #(
    parameter CLK_FREQ  = 30_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx_in,
    
    output logic [7:0] rx_data,
    output logic       rx_valid
);

    localparam CLK_PER_BIT      = CLK_FREQ / BAUD_RATE;
    localparam HALF_CLK_PER_BIT = CLK_PER_BIT / 2;
    
    // Double-Flop Synchronizer (Prevent Metastability)
    logic rx_sync_1, rx_sync;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_sync_1 <= 1'b1; // UART idle is HIGH
            rx_sync   <= 1'b1;
        end else begin
            rx_sync_1 <= rx_in;
            rx_sync   <= rx_sync_1;
        end
    end

    // UART RX State Machine
    typedef enum logic [1:0] {IDLE, START_BIT, DATA_BITS, STOP_BIT} state_t;
    state_t state;

    logic [15:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  shift_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            clk_cnt   <= 16'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            // Default pulse
            rx_valid <= 1'b0;

            case (state)
                IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    // Detect falling edge of start bit
                    if (rx_sync == 1'b0) begin
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    // Wait until the MIDDLE of the start bit
                    if (clk_cnt == HALF_CLK_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        if (rx_sync == 1'b0) begin
                            // Valid start bit.
                            state <= DATA_BITS;
                        end else begin
                            // Glitch detected, go back to idle
                            state <= IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA_BITS: begin
                    // Wait a full bit width to sample exactly in the middle of the next bit
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        shift_reg[bit_idx] <= rx_sync; // LSB first
                        
                        if (bit_idx == 3'd7) begin
                            state <= STOP_BIT;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STOP_BIT: begin
                    // Wait a full bit width to the middle of the stop bit
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        state   <= IDLE;
                        
                        // Output the byte and pulse valid
                        rx_data  <= shift_reg;
                        rx_valid <= 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
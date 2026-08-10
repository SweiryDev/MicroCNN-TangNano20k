`timescale 1ns/1ps

module uart_tx #(
    parameter CLK_FREQ  = 30_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic       clk,       
    input  logic       rst,       
    input  logic       tx_start,  // 1-cycle pulse to start transmission
    input  logic [7:0] tx_data,   // Data byte to send
    output logic       tx_out,    // Serial TX line
    output logic       tx_busy    // High when transmitting
);

    // Calculate clock ticks per baud bit
    localparam CLK_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    typedef enum logic [1:0] {IDLE, START_BIT, DATA_BITS, STOP_BIT} state_t;
    state_t state;

    logic [15:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  tx_shift_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            clk_cnt      <= 16'd0;
            bit_idx      <= 3'd0;
            tx_shift_reg <= 8'd0;
            tx_out       <= 1'b1; // Idle state is high
            tx_busy      <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out  <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        tx_shift_reg <= tx_data;
                        state        <= START_BIT;
                        tx_busy      <= 1'b1;
                    end
                end

                START_BIT: begin
                    tx_out <= 1'b0; // Start bit pulls line low
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        state   <= DATA_BITS;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA_BITS: begin
                    tx_out <= tx_shift_reg[bit_idx]; // Send LSB first
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
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
                    tx_out <= 1'b1; // Stop bit pulls line high
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        state   <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
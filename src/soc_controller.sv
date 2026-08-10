`timescale 1ns/1ps

module soc_controller (
    input  logic        clk,
    input  logic        rst,        
    input  logic [7:0]  rx_data,
    input  logic        rx_valid,
    output logic        img_we,
    output logic [9:0]  img_waddr,
    output logic [23:0] img_wdata,
    output logic        npu_rst_out 
);

    localparam CMD_LOAD  = 8'h4C; // 'L'
    localparam CMD_START = 8'h53; // 'S'

    typedef enum logic [2:0] { IDLE, LOAD_R, LOAD_G, LOAD_B, START_NPU } state_t;
    state_t state, next_state;

    logic [9:0] pixel_cnt;
    logic [7:0] r_buf, g_buf;
    logic       inc_pixel, clr_pixel;
    
    logic       hold_npu_in_reset;
    logic [3:0] rst_stretch;

    // Datapath & Registers
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_cnt         <= 10'd0;
            r_buf             <= 8'd0;
            g_buf             <= 8'd0;
            hold_npu_in_reset <= 1'b1; // Paralyze NPU on boot
            rst_stretch       <= 4'd0;
        end else begin
            if (clr_pixel) pixel_cnt <= 10'd0;
            else if (inc_pixel) pixel_cnt <= pixel_cnt + 1'b1;

            if (state == LOAD_R && rx_valid) r_buf <= rx_data;
            if (state == LOAD_G && rx_valid) g_buf <= rx_data;
            
            // Generate a wide, 15-cycle reset pulse to safely flush the datapath
            if (state == START_NPU) begin
                hold_npu_in_reset <= 1'b0; 
                rst_stretch       <= 4'd15; 
            end else if (rst_stretch > 0) begin
                rst_stretch <= rst_stretch - 1'b1;
            end
        end
    end

    // Next State Logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                // ONLY accept commands when idle to prevent pixel data collisions
                if (rx_valid) begin
                    if (rx_data == CMD_LOAD)       next_state = LOAD_R;
                    else if (rx_data == CMD_START) next_state = START_NPU;
                end
            end
            LOAD_R:    if (rx_valid) next_state = LOAD_G;
            LOAD_G:    if (rx_valid) next_state = LOAD_B;
            LOAD_B:    if (rx_valid) next_state = (pixel_cnt == 10'd783) ? IDLE : LOAD_R;
            START_NPU: next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end

    // Output Logic
    always_comb begin
        img_we      = 1'b0;
        img_waddr   = pixel_cnt;
        img_wdata   = 24'd0;
        inc_pixel   = 1'b0;
        clr_pixel   = 1'b0;
        
        // Assert reset if booting, stretching the pulse, or physical button pressed
        npu_rst_out = hold_npu_in_reset | (rst_stretch > 0) | rst;

        case (state)
            IDLE: clr_pixel = 1'b1;
            LOAD_B: begin
                if (rx_valid) begin
                    img_we    = 1'b1;
                    img_wdata = {r_buf, g_buf, rx_data}; 
                    inc_pixel = 1'b1;
                end
            end
            default: ;
        endcase
    end
endmodule
`timescale 1ns/1ps

// Controls the folding architecture for Conv2 using CHW dataflow.
// Iterates through the entire spatial map for a single filter 
// before moving to the next, natively matching the MaxPool cascade.

module conv2_fsm (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    
    // Line Buffer & RAM Control
    output logic [7:0] ram_raddr,   
    output logic       shift_en,
    
    // NPU / Folding Control
    output logic [3:0] filter_idx,  
    output logic       chunk_sel,   
    output logic       accumulate,  
    output logic       compute_en,
    
    // Status
    output logic       channel_done,
    output logic       layer_done
);

    typedef enum logic [2:0] {
        IDLE,
        SHIFT,
        COMPUTE_0,
        COMPUTE_1,
        NEXT_FILTER,
        DONE
    } state_t;
    
    state_t state, next_state;

    // Counters
    logic [7:0] pixel_cnt;         
    logic [3:0] filter_cnt;      
    
    // 2D Coordinates for Valid Window checking
    logic [4:0] lb_row; 
    logic [4:0] lb_col;
    logic       window_valid;

    // State Machine Registers
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            pixel_cnt <= 8'd0;
            filter_cnt <= 4'd0;
            lb_row <= 5'd0;
            lb_col <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    pixel_cnt <= 8'd0;
                    filter_cnt <= 4'd0;
                    lb_row <= 5'd0;
                    lb_col <= 5'd0;
                end
                
                SHIFT: begin
                    if (lb_col == 5'd12) begin 
                        lb_col <= 5'd0;
                        lb_row <= lb_row + 1'b1;
                    end else begin
                        lb_col <= lb_col + 1'b1;
                    end
                    pixel_cnt <= pixel_cnt + 1'b1;
                end
                
                COMPUTE_0: ; // Hold coordinates
                COMPUTE_1: ; // Hold coordinates
                
                NEXT_FILTER: begin
                    // Reset spatial coordinates, move to next filter
                    filter_cnt <= filter_cnt + 1'b1;
                    pixel_cnt <= 8'd0;
                    lb_row <= 5'd0;
                    lb_col <= 5'd0;
                end
                
                DONE: ; // Hold state
            endcase
        end
    end

    // Next State Logic
    assign window_valid = (lb_row >= 2) && (lb_col >= 2);

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SHIFT;
            end
            
            SHIFT: begin
                if (window_valid) begin
                    next_state = COMPUTE_0;
                end 
            end
            
            COMPUTE_0: begin
                next_state = COMPUTE_1;
            end
            
            COMPUTE_1: begin
                // If we just computed the final pixel (168), pixel_cnt is now 169
                if (pixel_cnt == 8'd169) begin
                    if (filter_cnt == 4'd15) begin
                        next_state = DONE;
                    end else begin
                        next_state = NEXT_FILTER;
                    end
                end else begin
                    next_state = SHIFT; 
                end
            end
            
            NEXT_FILTER: begin
                next_state = SHIFT;
            end
            
            DONE: begin
                next_state = DONE;
            end
        endcase
    end

    // Output Logic
    assign ram_raddr  = pixel_cnt;
    assign shift_en   = (state == SHIFT);
    
    assign filter_idx = filter_cnt;
    
    // Chunk 0 on first cycle, Chunk 1 on second cycle
    assign chunk_sel  = (state == COMPUTE_1);
    assign accumulate = (state == COMPUTE_1);
    assign compute_en = (state == COMPUTE_0) || (state == COMPUTE_1);

    assign channel_done = (state == NEXT_FILTER);    
    assign layer_done = (state == DONE);

endmodule
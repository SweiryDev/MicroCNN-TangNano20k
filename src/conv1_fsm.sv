`timescale 1ns/1ps

// Master controller for Layer 1. Orchestrates the Gowin BRAM IP 
// cores and the NPU datapath. 
// Image: 28x28 (784 pixels). Filters: 8.
// Weights & Bias: 1-cycle ultra-wide load.

module conv1_fsm (
    input  logic clk,
    input  logic rst,
    input  logic start,
    
    // Image ROM Interface (1-cycle latency)
    output logic [9:0] img_addr,     // 0 to 783
    output logic       img_en,       
    
    // Weight & Bias ROM Interface (1-cycle latency)
    output logic [2:0] filter_idx,   // 0 to 7 (Acts as address for both ROMs)
    output logic       weight_en,    
    output logic       bias_en,      
    
    // Datapath Control
    output logic       shift_en,       // Enables Line Buffer shifting
    output logic       compute_en,     // Enables NPU pipeline math
    
    // System Status
    output logic       layer_done
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_LOAD_WEIGHTS,
        ST_WAIT_BRAM,
        ST_STREAM,
        ST_FLUSH,
        ST_NEXT_FILTER
    } state_t;

    state_t state;

    // Internal Counters
    logic [9:0] pixel_cnt;
    logic [2:0] filter_cnt;
    logic [4:0] flush_cnt;

    // Internal request signals (to sync datapath with 1-cycle BRAM latency)
    logic req_shift;

    // ==========================================================================
    // 1. Pipeline Delay Register (Syncs datapath to BRAM data arrival)
    // ==========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            shift_en   <= 1'b0;
            compute_en <= 1'b0;
        end else begin
            shift_en   <= req_shift;
            // Compute enable stays high if we are shifting or flushing the pipeline
            compute_en <= req_shift | (state == ST_FLUSH);
        end
    end

    // ==========================================================================
    // 2. The Main State Machine
    // ==========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= ST_IDLE;
            pixel_cnt   <= 10'd0;
            filter_cnt  <= 3'd0;
            flush_cnt   <= 5'd0;
            
            img_addr    <= 10'd0;
            img_en      <= 1'b0;
            filter_idx  <= 3'd0;
            weight_en   <= 1'b0;
            bias_en     <= 1'b0;
            
            req_shift   <= 1'b0;
            layer_done  <= 1'b0;
        end else begin
            // Default pulldowns to prevent latches/glitches
            img_en     <= 1'b0;
            weight_en  <= 1'b0;
            bias_en    <= 1'b0;
            req_shift  <= 1'b0;
            layer_done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    pixel_cnt  <= 10'd0;
                    filter_cnt <= 3'd0;
                    flush_cnt  <= 5'd0;
                    if (start) state <= ST_LOAD_WEIGHTS;
                end
                
                // --------------------------------------------------------
                // Phase 1: Request Weights and Bias for current filter
                // --------------------------------------------------------
                ST_LOAD_WEIGHTS: begin
                    filter_idx <= filter_cnt;
                    weight_en  <= 1'b1;
                    bias_en    <= 1'b1;
                    
                    state <= ST_WAIT_BRAM;
                end
                
                // --------------------------------------------------------
                // Phase 2: 1-cycle wait for ultra-wide ROMs to output data
                // --------------------------------------------------------
                ST_WAIT_BRAM: begin
                    // Weights and Bias are now stable on the NPU inputs.
                    state <= ST_STREAM;
                end
                
                // --------------------------------------------------------
                // Phase 3: Stream the 28x28 Image
                // --------------------------------------------------------
                ST_STREAM: begin
                    img_en    <= 1'b1;
                    img_addr  <= pixel_cnt;
                    req_shift <= 1'b1; // delayed by 1 cycle in the top block

                    if (pixel_cnt == 10'd783) begin
                        pixel_cnt <= 10'd0;
                        state     <= ST_FLUSH;
                    end else begin
                        pixel_cnt <= pixel_cnt + 1'b1;
                    end
                end
                
                // --------------------------------------------------------
                // Phase 4: Wait for MaxPool pipeline to empty
                // --------------------------------------------------------
                ST_FLUSH: begin
                    // 15 cycles allows the final 2x2 pool to clear the registers
                    if (flush_cnt == 5'd15) begin 
                        flush_cnt <= 5'd0;
                        state     <= ST_NEXT_FILTER;
                    end else begin
                        flush_cnt <= flush_cnt + 1'b1;
                    end
                end
                
                // --------------------------------------------------------
                // Phase 5: Loop to next filter or Finish Layer
                // --------------------------------------------------------
                ST_NEXT_FILTER: begin
                    if (filter_cnt == 3'd7) begin // 8 filters complete
                        layer_done <= 1'b1;
                        state      <= ST_IDLE;
                    end else begin
                        filter_cnt <= filter_cnt + 1'b1;
                        state      <= ST_LOAD_WEIGHTS;
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
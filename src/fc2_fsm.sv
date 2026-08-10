`timescale 1ns/1ps

module fc2_fsm (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,

    // FC2 Buffer RAM read interface
    output logic [1:0] fc2_ram_raddr,    
    
    // Parameter ROM read interface
    output logic [4:0] weight_raddr,     
    output logic [2:0] bias_raddr,       
    output logic       param_en,

    // NPU / Datapath Control
    output logic       mult_ce,
    output logic       mult_clear,
    output logic       fc2_valid_out,
    output logic [2:0] current_neuron,
    output logic       layer_done
);

    typedef enum logic [2:0] {
        IDLE,
        CLEAR,
        COMPUTE,
        FLUSH,
        EMIT,
        DONE
    } state_t;

    state_t state, next_state;
    logic [2:0] neuron_cnt; // 0 to 7
    logic [1:0] chunk_cnt;  // 0 to 3
    logic [2:0] flush_cnt;  // 0 to 5

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            neuron_cnt <= 3'd0;
            chunk_cnt  <= 2'd0;
            flush_cnt  <= 3'd0;
        end else begin
            state <= next_state;
            
            if (state == IDLE) begin
                neuron_cnt <= 3'd0;
                chunk_cnt  <= 2'd0;
                flush_cnt  <= 3'd0;
            end else if (state == COMPUTE) begin
                chunk_cnt <= chunk_cnt + 1'b1;
            end else if (state == FLUSH) begin
                flush_cnt <= flush_cnt + 1'b1;
            end else if (state == EMIT) begin
                chunk_cnt <= 2'd0;
                flush_cnt <= 3'd0;
                if (neuron_cnt == 3'd7) neuron_cnt <= 3'd0;
                else                    neuron_cnt <= neuron_cnt + 1'b1;
            end
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (start) next_state = CLEAR;
            CLEAR:   next_state = COMPUTE;
            COMPUTE: if (chunk_cnt == 2'd3) next_state = FLUSH;
            // Wait 6 cycles for the final chunk to emerge from the NPU pipeline
            FLUSH:   if (flush_cnt == 3'd5) next_state = EMIT; 
            EMIT:    if (neuron_cnt == 3'd7) next_state = DONE;
                     else next_state = CLEAR;
            DONE:    next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    assign fc2_ram_raddr  = chunk_cnt;
    assign weight_raddr   = {neuron_cnt, chunk_cnt};
    assign bias_raddr     = neuron_cnt;
    
    // Control Mapping
    assign param_en       = (state == COMPUTE);
    assign mult_ce        = (state == COMPUTE || state == FLUSH); // Keep pipeline moving
    assign mult_clear     = (state == CLEAR);
    assign fc2_valid_out  = (state == EMIT);
    assign current_neuron = neuron_cnt;
    assign layer_done     = (state == DONE);

endmodule
`timescale 1ns/1ps

// Pure control plane for the Fully Connected 1 layer.
// Drives memory addresses for the FC1 Buffer RAM and Parameter ROMs.
// Manages the NPU array control signals and the 3-cycle pipeline drain.

module fc1_fsm (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    
    // Memory Address Outputs
    output logic [5:0]  fc1_ram_raddr,    // 0 to 49 (Chunk address)
    output logic [10:0] fc1_weight_raddr, // 0 to 1599 (Neuron * 50 + Chunk)
    output logic [4:0]  fc1_bias_raddr,   // 0 to 31 (Neuron address)
    output logic        param_en,         // Enable signal for ROM reads
    
    // NPU Array Control
    output logic        mult_ce,          // Enable NPU pipeline
    output logic        mult_clear,       // Wipe accumulators before new neuron
    
    // Downstream Control (Reduction Tree / FC2 RAM)
    output logic        fc1_valid_out,    // Pulses high when a neuron's sum is ready
    output logic [4:0]  current_neuron,   // Tells the downstream logic which neuron finished
    output logic        layer_done        // Master pipeline status
);

    // State Machine Definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT_NEURON,     // Wipes DSP accumulators for 1 cycle
        FETCH_COMPUTE,   // 50-cycle loop to feed the NPU array
        DRAIN_PIPELINE,  // 3-cycle wait for the final MAC operations to finish
        WRITE_OUT,       // 1-cycle pulse to write the final reduced sum
        DONE
    } fsm_state_t;

    fsm_state_t state, next_state;

    // Counters
    logic [5:0] chunk_cnt;  // 0 to 49
    logic [4:0] neuron_cnt; // 0 to 31
    logic [1:0] drain_cnt;  // 0 to 2

    // FSM Sequential Logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            chunk_cnt  <= 6'd0;
            neuron_cnt <= 5'd0;
            drain_cnt  <= 2'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    chunk_cnt  <= 6'd0;
                    neuron_cnt <= 5'd0;
                end
                
                INIT_NEURON: begin
                    chunk_cnt <= 6'd0;
                    drain_cnt <= 2'd0;
                end
                
                FETCH_COMPUTE: begin
                    if (chunk_cnt < 6'd49) begin
                        chunk_cnt <= chunk_cnt + 1'b1;
                    end
                end
                
                DRAIN_PIPELINE: begin
                    drain_cnt <= drain_cnt + 1'b1;
                end
                
                WRITE_OUT: begin
                    neuron_cnt <= neuron_cnt + 1'b1;
                end
            endcase
        end
    end

    // FSM Combinatorial Control Logic
    always_comb begin
        next_state    = state;
        mult_ce       = 1'b0;
        mult_clear    = 1'b0;
        param_en      = 1'b0;
        fc1_valid_out = 1'b0;
        layer_done    = 1'b0;

        case (state)
            IDLE: begin
                if (start) next_state = INIT_NEURON;
            end
            
            INIT_NEURON: begin
                mult_clear = 1'b1; // Pulse NPU reset to wipe previous neuron's data
                next_state = FETCH_COMPUTE;
            end
            
            FETCH_COMPUTE: begin
                mult_ce  = 1'b1; 
                param_en = 1'b1; 
                if (chunk_cnt == 6'd49) begin
                    next_state = DRAIN_PIPELINE;
                end
            end
            
            DRAIN_PIPELINE: begin
                mult_ce = 1'b1; // Keep NPU pipeline moving for the final chunks
                if (drain_cnt == 2'd2) begin
                    next_state = WRITE_OUT;
                end
            end
            
            WRITE_OUT: begin
                fc1_valid_out = 1'b1; // Tell the reduction tree to latch the result
                if (neuron_cnt == 5'd31) begin
                    next_state = DONE;
                end else begin
                    next_state = INIT_NEURON;
                end
            end
            
            DONE: begin
                layer_done = 1'b1;
            end
        endcase
    end

    // Address Routing Assignments
    assign fc1_ram_raddr    = chunk_cnt;
    assign fc1_bias_raddr   = neuron_cnt;
    assign current_neuron   = neuron_cnt;
    
    // 50 chunks per neuron. Multiplication by 50 is fine combinatorially 
    // at 27MHz, synthesis will map it efficiently.
    assign fc1_weight_raddr = (neuron_cnt * 11'd50) + {5'd0, chunk_cnt};

endmodule
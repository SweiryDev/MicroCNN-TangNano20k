`timescale 1ns/1ps

// Master controller for the cascaded NPU pipeline. 
// Sequences Conv1 -> Conv2 -> FC1 -> FC2/Argmax and manages the global layer state.

module master_pipeline_fsm (
    input  logic clk,
    input  logic rst,
    
    // Status signals from individual layer FSMs
    input  logic conv1_layer_done,
    input  logic conv2_layer_done,
    input  logic fc1_layer_done,
    input  logic fc2_layer_done,   // Asserted by argmax_done
    
    // 1-cycle start triggers to layer FSMs
    output logic conv1_start,
    output logic conv2_start,
    output logic fc1_start,
    output logic fc2_start,
    
    // Global routing state (0 = Conv1 TDM active, 1 = Conv2 TDM active)
    output logic layer_state,  
    
    // Global completion flag
    output logic system_done,

    output logic npu_sleep
);

    // State Definitions
    typedef enum logic [3:0] {
        IDLE,
        RUN_CONV1,
        WAIT_CONV1,
        RUN_CONV2,
        WAIT_CONV2,
        RUN_FC1,
        WAIT_FC1,
        RUN_FC2,
        WAIT_FC2,
        DONE
    } master_state_t;

    master_state_t state, next_state;

    // Sequential Logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                next_state = RUN_CONV1;
            end
            
            RUN_CONV1: begin
                next_state = WAIT_CONV1;
            end
            
            WAIT_CONV1: begin
                if (conv1_layer_done) next_state = RUN_CONV2;
            end
            
            RUN_CONV2: begin
                next_state = WAIT_CONV2;
            end
            
            WAIT_CONV2: begin
                if (conv2_layer_done) next_state = RUN_FC1;
            end
            
            RUN_FC1: begin
                next_state = WAIT_FC1;
            end
            
            WAIT_FC1: begin
                if (fc1_layer_done) next_state = RUN_FC2;
            end

            RUN_FC2: begin
                next_state = WAIT_FC2;
            end

            WAIT_FC2: begin
                if (fc2_layer_done) next_state = DONE;
            end
            
            DONE: begin
                next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always_comb begin
        // Default assignments
        conv1_start = 1'b0;
        conv2_start = 1'b0;
        fc1_start   = 1'b0;
        fc2_start   = 1'b0;
        system_done = 1'b0;
        layer_state = 1'b0; 
        npu_sleep = 1'b0;

        case (state)
            IDLE: begin
                npu_sleep = 1'b1;
            end

            RUN_CONV1: begin
                conv1_start = 1'b1;
                layer_state = 1'b0; 
            end
            
            WAIT_CONV1: begin
                layer_state = 1'b0; 
            end
            
            RUN_CONV2: begin
                conv2_start = 1'b1;
                layer_state = 1'b1; 
            end
            
            WAIT_CONV2: begin
                layer_state = 1'b1;
            end
            
            RUN_FC1: begin
                fc1_start   = 1'b1;
                layer_state = 1'b1; 
            end
            
            WAIT_FC1: begin
                layer_state = 1'b1;
            end

            RUN_FC2: begin
                fc2_start   = 1'b1;
                layer_state = 1'b1;
            end

            WAIT_FC2: begin
                layer_state = 1'b1;
            end
            
            DONE: begin
                system_done = 1'b1;
                layer_state = 1'b1;
                npu_sleep = 1'b1;
            end
            
            default: ;
        endcase
    end

endmodule
`timescale 1ns/1ps

// -- Red Channel ROM Reader --
module img_r_rom_read (
    output logic [7:0] dout,
    input  logic       clk,
    input  logic       ce,
    input  logic       reset,
    input  logic [9:0] ad
);

    // 1024 depth to safely cover the 28x28 (784) image size
    logic [7:0] mem [0:1023]; 

    initial begin
        $readmemh("hardware_roms/img_r.hex", mem);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            dout <= 8'd0;
        end else if (ce) begin
            dout <= mem[ad];
        end
    end

endmodule

// -- Green Channel ROM Reader --
module img_g_rom_read (
    output logic [7:0] dout,
    input  logic       clk,
    input  logic       ce,
    input  logic       reset,
    input  logic [9:0] ad
);

    logic [7:0] mem [0:1023]; 

    initial begin
        $readmemh("hardware_roms/img_g.hex", mem);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            dout <= 8'd0;
        end else if (ce) begin
            dout <= mem[ad];
        end
    end

endmodule

// -- Blue Channel ROM Reader --
module img_b_rom_read (
    output logic [7:0] dout,
    input  logic       clk,
    input  logic       ce,
    input  logic       reset,
    input  logic [9:0] ad
);

    logic [7:0] mem [0:1023]; 

    initial begin
        $readmemh("hardware_roms/img_b.hex", mem);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            dout <= 8'd0;
        end else if (ce) begin
            dout <= mem[ad];
        end
    end

endmodule
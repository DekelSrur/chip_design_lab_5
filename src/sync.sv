`timescale 1ns / 1ps


module sync (
    input  logic clk,
    input  logic cpu_resetn,
    input  logic btnc,
    input  logic [14:0] sw, 

    output logic rst,
    output logic bntc_s,
    output logic [14:0] sw_s
);

// reset: invert and syncronise
    logic [1:0] rst_ff = 2'b11;
    always_ff @(posedge clk)
        rst_ff <= {rst_ff[0], ~cpu_resetn};
    assign rst = rst_ff[1];   

// buttons and switches
    logic [1:0] btn_ff = 2'b00;
    logic [14:0] sw_ff1 = 15'd0, sw_ff2 = 15'd0;

    always_ff @(posedge clk) begin
        btn_ff <= {btn_ff[0], btnc};
        sw_ff1 <= sw;
        sw_ff2 <= sw_ff1;
    end

    assign bntc_s = btn_ff[1];
    assign sw_s = sw_ff2;    

endmodule

`timescale 1ns / 1ps

module cfg_latch(
    input  logic clk,
    input  logic rst,
    input  logic btn_db,
    input  logic busy,
    input  logic [14:0] sw_s,

    output logic start,
    output logic [7:0] byte_val,
    output logic [1:0] speed_sel,
    output logic [1:0] count_sel
);

    logic btn_d;
    logic press;

    assign press = btn_db & ~btn_d;

    always_ff @(posedge clk) begin         //on every rising clock
        if (rst) begin
            btn_d <= 1'b0;
            start <= 1'b0;
            byte_val <= 8'h00;
            speed_sel <= 2'd0;
            count_sel <= 2'd0;  
        end

        else begin                      //normal operation
            btn_d <= btn_db;
            start <= 1'b0;

            if (press && !busy) begin   //new press while IDLE       
                start <= 1'b1;
                byte_val <= sw_s[7:0];
                speed_sel <= sw_s[9:8];
                count_sel <= sw_s[14:13];
            end    
        end 

    end

endmodule

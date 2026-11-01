`timescale 1ns / 1ps

module debouncer #(
    parameter int DEBOUNCE_CYCLES = 1_000_000
)(
    input  logic clk,
    input  logic rst,
    input  logic btn_in,

    output logic btn_db
);

    localparam int CW = (DEBOUNCE_CYCLES > 1) ? $clog2(DEBOUNCE_CYCLES) : 1 ; //counter width
    logic [CW-1:0] cnt;                                                       // window counter

    always_ff @(posedge clk) begin                  //zero coutner when reset
        if (rst) begin
            cnt <= '0;
            btn_db <= 1'b0;
        end

        else if (btn_in == btn_db) begin            //if exit == entry, then we dont change 
            cnt <= '0;
        end

        else if (cnt == CW'(DEBOUNCE_CYCLES - 1)) begin   //exit != entry, change
            btn_db <= btn_in;
            cnt <= '0;
        end  

        else begin
            cnt <= cnt + 1'b1;                      //add bit if going into next cycle
        end
    end

endmodule

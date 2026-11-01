`timescale 1ns / 1ps

module uart_tx #( 
    parameter int CLKS_PER_BIT = 1736                   // 100Mhz/57600 = 1736
)(
    input  logic clk,
    input  logic rst,
    input  logic tx_start,
    input  logic [7:0] tx_data,

    output logic tx,
    output logic tx_busy,
    output logic tx_done
);

    localparam int BCW = $clog2(CLKS_PER_BIT);          //baud counter: 1736 -> 11 bit
    logic [BCW-1:0] baud_cnt;                           //clocks inside the curent bit
    logic [3:0] bit_idx;
    logic [9:0] shift_reg;

    always_ff @(posedge clk) begin
        tx_done <= 1'b0;                                //default: tx_done=0

        if (rst) begin                              //reset
            tx <= 1'b1;
            tx_busy <= 1'b0;
            baud_cnt <= '0;
            bit_idx <= 4'd0;
            shift_reg <= 10'h3FF;
        end

        else if (!tx_busy) begin                    //IDLE
            if (tx_start) begin                     //tx_start
                shift_reg <= {1'b1 , tx_data , 1'b0};
                tx <= 1'b0;
                tx_busy <= 1'b1;
                baud_cnt <= '0;  
                bit_idx <= 4'd0;
            end
        end

        else begin                                  //busy
            if (baud_cnt == BCW'(CLKS_PER_BIT - 1)) begin  //current bit has reached CLKS_PER_BIT
                baud_cnt <= '0;

                if (bit_idx == 4'd9) begin
                    tx_busy <= 1'b0;
                    tx_done <= 1'b1;
                    tx <= 1'b1;
                end

                else begin                          //move to the next bit
                    shift_reg <= {1'b1, shift_reg[9:1]};
                    tx <= shift_reg[1];
                    bit_idx <= bit_idx + 1'b1;
                end

            end

            else begin                              //bit not finished yet
                baud_cnt <= baud_cnt + 1'b1;
            end
        end                    
    end

endmodule

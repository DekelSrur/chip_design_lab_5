`timescale 1ns / 1ps
module tb_seg7_ctrl;

logic clk, rst_n;
logic [31:0] digits;
logic [7:0] an, dps;
logic [6:0] seg;
logic dp;

seg7_ctrl dut(
    .clk(clk), .rst_n(rst_n),
    .digits(digits), .an(an), .dps(dps),
    .seg(seg),
    .dp(dp)
);

task automatic reset_check(input clk, input rst_n);
    @(posedge clk); 
    rst_n = 0; 
    @(negedge clk);
    rst_n = 1;
endtask
initial clk = 1'b0;
always #5 clk = ~clk;

initial begin
    $monitor("t=%0d ns  rst_n=%b  digits=%h  dps=%b  an=%b  seg=%b  dp=%b",
                 $time, rst_n,    digits,    dps,    an,    seg,    dp);
    rst_n = 1;
    digits = 32'b0;
    dps = 8'b0;
    reset_check(clk, rst_n); //activates a reset pulse, make sure to see idx<=3d'0, an<=8'hFF, seg<=7'h7F, dp<=1'b1
    assert(an != 8'hFF || seg != 7'h7F || !dp);
    



end

endmodule

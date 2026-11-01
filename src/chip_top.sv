`timescale 1ns / 1ps

module chip_top#(
    parameter int CLKS_PER_BIT = 1736,          // 100 Mhz/57,600 bps = 1736
    parameter int DEBOUNCE_CYCLES = 1_000_000,  //debounce window: 10ms
    parameter int DELAY_50MS = 5_000_000,
    parameter int DELAY_100MS = 10_000_000,
    parameter int DELAY_200MS = 20_000_000,
    parameter int REFRESH_DIV = 25_000      //100MHz/25,000 = 4000Hz, 4000Hz/8 = 500Hz
)(
    input  logic clk,
    input  logic cpu_resetn,
    input  logic btnc,
    input  logic [15:0] sw,

    output logic uart_txd,
    output logic led,
    output logic [7:0] an,
    output logic [6:0] seg,
    output logic dp
);
//internal wires
    logic rst;
    logic bntc_s;
    logic btn_db;
    logic [14:0] sw_s;
    logic start;
    logic busy;
    logic [7:0] byte_val;
    logic [1:0] speed_sel, count_sel;
    logic tx_start;
    logic tx_busy;
    logic tx_done;
    logic [7:0] tx_data;
    logic [8:0] rows_sent;
    logic [16:0] bytes_sent;
    logic [31:0] digits;
    logic [7:0] dps;

//blocks
    sync u_sync (
    .clk(clk), .cpu_resetn(cpu_resetn), .btnc(btnc), .sw(sw[14:0]),
    .rst(rst), .bntc_s(bntc_s), .sw_s(sw_s)
    );

    debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) 
    u_debouncer (.clk(clk), .rst(rst), .btn_in(bntc_s), .btn_db(btn_db)
    );

    cfg_latch u_cfg_latch (
        .clk(clk), .rst(rst), .btn_db(btn_db), .busy(busy), .sw_s(sw_s),
        .start(start), .byte_val(byte_val), .speed_sel(speed_sel), 
        .count_sel(count_sel)
    );

    tx_fsm #(.DELAY_50MS(DELAY_50MS), .DELAY_100MS(DELAY_100MS), .DELAY_200MS(DELAY_200MS))
    u_tx_fsm (.clk(clk), .rst(rst), .start(start), .byte_val(byte_val),
    .speed_sel(speed_sel), .count_sel(count_sel), .tx_done(tx_done), .tx_start(tx_start),
    .tx_data(tx_data), .led(led), .busy(busy), .rows_sent(rows_sent),
    .bytes_sent(bytes_sent)
    );

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_uart_tx (
        .clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
        .tx(uart_txd), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    display_mux u_display_mux (
        .byte_val(byte_val), .speed_sel(speed_sel), .count_sel(count_sel),
        .rows_sent(rows_sent), .digits(digits), .dps(dps)
    );

    seg7_ctrl #(.REFRESH_DIV(REFRESH_DIV)) u_seg7_ctrl (
        .clk(clk), .rst(rst), .digits(digits), .dps(dps),
        .an(an), .seg(seg), .dp(dp)
    );

endmodule

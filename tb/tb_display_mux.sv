`timescale 1ns / 1ps

module tb_display_mux;

    logic rx_mode = 0;                   // 0 = TX layout, 1 = RX layout
    logic [7:0] byte_val = '0;
    logic [1:0] speed_sel = '0, count_sel = '0;
    logic [8:0] rows_sent = '0;
    logic [7:0] row_idx = '0, col_idx = '0, pix_val = '0;
    logic [31:0] digits;                 // 8 hex digits: T3 T2 T1 T0
    logic [7:0] dps;
    
    int errors = 0;

    // combinational module - no clock
    display_mux dut (.rx_mode(rx_mode), .byte_val(byte_val), .speed_sel(speed_sel),
                     .count_sel(count_sel), .rows_sent(rows_sent), .row_idx(row_idx),
                     .col_idx(col_idx), .pix_val(pix_val),
                     .digits(digits), .dps(dps));

    initial begin

        // test 1: TX - 32x32, 0.5, byte A5, 32 rows sent "20 20 0.5 A5"
        count_sel = 1; speed_sel = 1; byte_val = 8'hA5; rows_sent = 32;
        #1;                                     // let the combinational logic settle
        if (digits !== 32'h2020_05A5 || dps !== 8'b0000_1000) begin   // point on T1
            $display("Test 1 FAILED: digits = %h", digits);
            errors++;
        end
        else
            $display("Test 1 PASSED: digits = %h", digits);

        // test 2: TX - 256x256, 2.0, byte FF, 256 rows sent "FF FF 2.0 FF"
        count_sel = 3; speed_sel = 3; byte_val = 8'hFF; rows_sent = 256;
        #1;
        if (digits !== 32'hFFFF_20FF) begin     // 256 does not fit in 2 digits -> FF
            $display("Test 2 FAILED: digits = %h", digits);
            errors++;
        end
        else
            $display("Test 2 PASSED: digits = %h", digits);

        // test 3: TX - 128x128, 1.0, byte 3C, 100 rows sent "64 80 1.0 3C"
        count_sel = 2; speed_sel = 2; byte_val = 8'h3C; rows_sent = 100;   // 100 = 0x64
        #1;
        if (digits !== 32'h6480_103C) begin
            $display("Test 3 FAILED: digits = %h", digits);
            errors++;
        end
        else
            $display("Test 3 PASSED: digits = %h", digits);

        // test 4: TX - 1x1, 0.0, byte 00, 1 row sent "01 01 0.0 00"
        count_sel = 0; speed_sel = 0; byte_val = 8'h00; rows_sent = 1;
        #1;
        if (digits !== 32'h0101_0000) begin
            $display("Test 4 FAILED: digits = %h", digits);
            errors++;
        end
        else
            $display("Test 4 PASSED: digits = %h", digits);

        // test 5: RX - row 12, column AB, pixel 7F "12 AB 00 7F", no decimal point
        //         (T1 is turned into "--" later, inside seg7_ctrl)
        rx_mode = 1; row_idx = 8'h12; col_idx = 8'hAB; pix_val = 8'h7F;
        #1;
        if (digits !== 32'h12AB_007F || dps !== 0) begin
            $display("Test 5 FAILED: digits = %h", digits);
            errors++;
        end
        else
            $display("Test 5 PASSED: digits = %h", digits);

        // test 6: in RX mode the TX inputs have no effect
        byte_val = 8'h55; speed_sel = 1; count_sel = 1; rows_sent = 7;
        #1;
        if (digits !== 32'h12AB_007F) begin
            $display("Test 6 FAILED: digits = %h", digits);
            errors++;
        end
        else
            $display("Test 6 PASSED: TX inputs ignored in RX mode");

        if (errors == 0) $display("tb_display_mux PASSED");
        else             $display("tb_display_mux FAILED, %0d errors", errors);
        $finish;
    end

endmodule
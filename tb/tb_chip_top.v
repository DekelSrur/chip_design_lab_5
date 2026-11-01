`timescale 1ns / 1ps

module tb_chip_top;                        

    localparam CPB   = 8;                  // clocks per bit in simulation
    localparam T_CLK = 10;                 // clock period in ns
    localparam T_BIT = CPB * T_CLK;        // one bit in ns

    reg clk = 0, cpu_resetn = 0, btnc = 0; 
    reg [15:0] sw = 16'h0000;             
    wire uart_txd, led, dp;         
    wire [7:0] an;
    wire [6:0] seg;

    integer errors = 0;                    

    always #(T_CLK/2) clk = ~clk;          // 100 MHz clock

    chip_top #(                            
        .CLKS_PER_BIT(CPB), .DEBOUNCE_CYCLES(10),          // debounce 10 clocks = 100 ns
        .DELAY_50MS(20), .DELAY_100MS(40), .DELAY_200MS(80),
        .REFRESH_DIV(4)                                    // next digit every 4 clocks
    ) dut (
        .clk(clk), .cpu_resetn(cpu_resetn), .btnc(btnc), .sw(sw),
        .uart_txd(uart_txd), .led(led), .an(an), .seg(seg), .dp(dp)
    );

    //UART receiver model
    reg [7:0] rx_char [0:8191];            // every received character
    integer   rx_n = 0, b;                 // number received; bit loop index
    reg [7:0] r;                           // character being rebuilt
    initial forever begin                  // background process
        @(negedge uart_txd);               // start bit begins
        #(T_BIT/2);                        // middle of the start bit
        for (b = 0; b < 8; b = b + 1) begin #(T_BIT); r[b] = uart_txd; end // 8 data bits, LSB first
        #(T_BIT);                          // middle of the stop bit
        rx_char[rx_n] = r;                 // store
        rx_n = rx_n + 1;
    end

    //helpers
    task set_sw(input [7:0] bv, input [1:0] sp, input [1:0] cs); 
        sw = {1'b0, cs, 3'b000, sp, bv};   // SW15=0 | SW14:13=count | SW12:10=0 | SW9:8=speed | SW7:0=byte
    endtask

    task press;                            // press and release the button with contact bounce
        integer k;
        begin
            for (k = 0; k < 4; k = k + 1) begin btnc = 1; #(30); btnc = 0; #(20); end // 4 short bounces (< 100 ns)
            btnc = 1; #(400);              // stable press, longer than the 100 ns debounce window
            for (k = 0; k < 4; k = k + 1) begin btnc = 0; #(30); btnc = 1; #(20); end // bounces on release
            btnc = 0; #(400);              // stable release
        end
    endtask

    function [6:0] hex2seg(input [3:0] h); // independent copy of the segment table (reference model)
        case (h)
            4'h0: hex2seg = 7'b1000000; 4'h1: hex2seg = 7'b1111001;
            4'h2: hex2seg = 7'b0100100; 4'h3: hex2seg = 7'b0110000;
            4'h4: hex2seg = 7'b0011001; 4'h5: hex2seg = 7'b0010010;
            4'h6: hex2seg = 7'b0000010; 4'h7: hex2seg = 7'b1111000;
            4'h8: hex2seg = 7'b0000000; 4'h9: hex2seg = 7'b0010000;
            4'hA: hex2seg = 7'b0001000; 4'hB: hex2seg = 7'b0000011;
            4'hC: hex2seg = 7'b1000110; 4'hD: hex2seg = 7'b0100001;
            4'hE: hex2seg = 7'b0000110; default: hex2seg = 7'b0001110;
        endcase
    endfunction

    //read all 8 digits from the multiplexed outputs and compare with the expected values
    task check_display(input [31:0] exp_digits, input [7:0] exp_dps, input [8*8-1:0] name);
        integer d;                         // digit index
        reg [7:0] seen_mask;               // one bit per digit: 1 = already checked
        begin
            seen_mask = 8'h00;             // nothing checked yet
            while (seen_mask != 8'hFF) begin // until all 8 digits were seen:
                @(negedge clk);            //   sample in the middle of the clock period
                for (d = 0; d < 8; d = d + 1) begin
                    if (an == ~(8'h01 << d)) begin // digit d is lit now:
                        if (seg !== hex2seg(exp_digits[d*4 +: 4]) || dp !== ~exp_dps[d]) begin // wrong segments or point
                            if (!seen_mask[d]) begin // report each digit once
                                $display("ERROR %s: digit %0d shows seg=%b dp=%b, expected %h%s",
                                         name, d, seg, dp, exp_digits[d*4 +: 4], exp_dps[d] ? "." : "");
                                errors = errors + 1;
                            end
                        end
                        seen_mask[d] = 1'b1; // mark digit d as checked
                    end
                end
            end
            $display("%s display OK: digits = %h, points = %b", name, exp_digits, exp_dps);
        end
    endtask

    integer s, k, bad;                     // first char index, loop index, unexpected char count

    initial begin                          // main test sequence
        $timeformat(-9, 0, " ns", 10);     // print times in ns
        $dumpfile("tb_chip_top.vcd"); $dumpvars(0, tb_chip_top); // save waveforms

        //reset
        #(100); cpu_resetn = 1; #(100);    // hold reset 100 ns, release, wait
        if (uart_txd !== 1'b1) begin $display("ERROR: UART line not idle after reset"); errors = errors + 1; end

        //test 1: one byte
        set_sw(8'h41, 2'd0, 2'd0);         // byte 41, no delay, N = 1
        s = rx_n;
        press;                             // bouncing press
        wait (dut.busy == 1'b0);           // internal signal: wait for the end of the transmission
        #(20*T_BIT);                       // let the receiver finish
        $display("Test 1: %0d chars: %02h %02h %02h %02h, LED=%b",
                 rx_n - s, rx_char[s], rx_char[s+1], rx_char[s+2], rx_char[s+3], led);
        if (rx_n - s != 4 || rx_char[s] != 8'h41 || rx_char[s+1] != 8'h20 ||
            rx_char[s+2] != 8'h0D || rx_char[s+3] != 8'h0A) begin  // exactly 41 20 0D 0A
            $display("ERROR: test 1 stream"); errors = errors + 1;
        end
        if (led !== 1'b1) begin $display("ERROR: LED should be on after byte 0"); errors = errors + 1; end
        //             T3 T2 T1 T0          dp: T3 T2 T1 T0
        check_display(32'h01_01_00_41, 8'b00_00_10_00, "Test 1");   // 01 | 01 | 0.0 | 41

        //test 2: 32 x 32, changes during transfer must be ignored
        set_sw(8'h55, 2'd1, 2'd1);         // byte 55, 50 ms, N = 32
        s = rx_n;
        press;
        #(3000);                           // in the middle of the transfer:
        set_sw(8'h66, 2'd3, 2'd0);         //   change the switches
        press;                             //   and press again -> both must be ignored
        wait (dut.busy == 1'b0);
        #(20*T_BIT);
        bad = 0;
        for (k = s; k < rx_n; k = k + 1)   // count characters that are not 55 / 20 / 0D / 0A
            if (rx_char[k] != 8'h55 && rx_char[k] != 8'h20 && rx_char[k] != 8'h0D && rx_char[k] != 8'h0A) bad = bad + 1;
        $display("Test 2: %0d chars (expected 2112), %0d unexpected, LED=%b, rows=%0d",
                 rx_n - s, bad, led, dut.rows_sent);
        if (rx_n - s != 2112 || bad != 0) begin $display("ERROR: test 2 stream"); errors = errors + 1; end
        if (led !== 1'b0) begin $display("ERROR: LED after byte 1023 should be off"); errors = errors + 1; end
        check_display(32'h20_20_05_55, 8'b00_00_10_00, "Test 2");   // 20 | 20 | 0.5 | 55

        //test 3: display of 256
        set_sw(8'hC3, 2'd3, 2'd3);         // byte C3, 200 ms, N = 256
        press;
        #(200);
        check_display(32'h00_FF_20_C3, 8'b00_00_10_00, "Test 3");   // 00 | FF | 2.0 | C3
        cpu_resetn = 0; #(100); cpu_resetn = 1; #(100);              // reset in the middle of the transfer
        if (dut.busy !== 1'b0) begin $display("ERROR: reset did not stop the transfer"); errors = errors + 1; end

        if (errors == 0) $display("\n*** tb_chip_top PASSED ***\n");        // summary
        else             $display("\n*** tb_chip_top FAILED: %0d errors ***\n", errors);
        $finish;                           // end the simulation
    end

endmodule                                  // end of module tb_chip_top
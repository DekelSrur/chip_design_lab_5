`timescale 1ns/1ps

module tb_sync;

    logic clk = 0;
    logic cpu_resetn = 1;           //reset button not pressed
    logic btnc = 0;
    logic [15:0] sw = '0;
    logic uart_rxd = 1;             //uart line idle high
    logic rst_n, btnc_s, rxd_s;
    logic [15:0] sw_s;

    int errors = 0;

    sync dut (.clk(clk), .cpu_resetn(cpu_resetn), .btnc(btnc), .sw(sw), .uart_rxd(uart_rxd),
              .rst_n(rst_n), .btnc_s(btnc_s), .sw_s(sw_s), .rxd_s(rxd_s));

    always #5 clk = ~clk;           //100 MHz 

    initial begin

        // test 1: power-up - design starts in reset, released after 2 clocks
        #1;
        if (rst_n !== 0 || rxd_s !== 1) begin
            $display("Test 1 FAILED: power-up values");
            errors++;
        end
        @(posedge clk);
        @(posedge clk);
        #1;
        if (rst_n !== 1) begin
            $display("Test 1 FAILED: reset not released after 2 clocks");
            errors++;
        end

        // test 2: reset button pressed between clock edges - rst_n goes low at once
        #2 cpu_resetn = 0;
        #1;
        if (rst_n !== 0) begin
            $display("Test 2 FAILED: reset is not asynchronous");
            errors++;
        end

        // test 3: button released - rst_n returns to 1 only after 2 clocks
        @(negedge clk) cpu_resetn = 1;
        @(posedge clk);
        #1;
        if (rst_n !== 0) begin
            $display("Test 3 FAILED: reset released after 1 clock");
            errors++;
        end
        @(posedge clk);
        #1;
        if (rst_n !== 1) begin
            $display("Test 3 FAILED: reset not released after 2 clocks");
            errors++;
        end

        // test 4: inputs reach the outputs after 2 clocks (2-FF synchroniser)
        @(negedge clk);
        btnc     = 1;
        sw       = 16'hA5C3;
        uart_rxd = 0;
        @(posedge clk);
        #1;
        if (btnc_s !== 0 || sw_s !== 16'h0000 || rxd_s !== 1) begin
            $display("Test 4 FAILED: outputs changed after 1 clock");
            errors++;
        end
        @(posedge clk);
        #1;
        if (btnc_s !== 1 || sw_s !== 16'hA5C3 || rxd_s !== 0) begin
            $display("Test 4 FAILED: outputs not updated after 2 clocks");
            errors++;
        end

        if (errors == 0) $display("tb_sync PASSED");
        else             $display("tb_sync FAILED, %0d errors", errors);
        $finish;
    end

endmodule




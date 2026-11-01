`timescale 1ns / 1ps                       
module tb_tx_fsm;                          

    localparam CPB   = 8;                  
    localparam T_CLK = 10;                      // clock period in ns
    localparam T_BIT = CPB * T_CLK;             // one bit in ns (80 ns)
    localparam D50 = 20, D100 = 40, D200 = 80;  // reduced delays in clocks

    reg clk = 0, rst = 1, start = 0;            
    reg [7:0] byte_val  = 8'h00;                      
    reg [1:0] speed_sel = 2'd0, count_sel = 2'd0;     
    wire tx_start, tx_done, tx_busy, tx, led, busy; 
    wire [7:0] tx_data;                                
    wire [8:0] rows_sent;                              
    wire [16:0] bytes_sent;                            

    integer errors = 0;                    

    always #(T_CLK/2) clk = ~clk;               // 100 MHz clock

    tx_fsm #(.DELAY_50MS(D50), .DELAY_100MS(D100), .DELAY_200MS(D200)) dut ( 
        .clk(clk), .rst(rst), .start(start), .byte_val(byte_val),
        .speed_sel(speed_sel), .count_sel(count_sel), .tx_done(tx_done),
        .tx_start(tx_start), .tx_data(tx_data), .led(led), .busy(busy),
        .rows_sent(rows_sent), .bytes_sent(bytes_sent)
    );

    uart_tx #(.CLKS_PER_BIT(CPB)) phy (    
        .clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    //reciver model
    reg [7:0] rx_char [0:8191];            // every received character (3 tests > 4096 chars)
    real      rx_time [0:8191];            // start time of every received character
    integer   rx_n = 0, b;                 
    reg [7:0] r;                           
    initial forever begin                 
        @(negedge tx);                     
        rx_time[rx_n] = $realtime;         
        #(T_BIT/2);                        
        for (b = 0; b < 8; b = b + 1) begin// sample 8 data bits, LSB first
            #(T_BIT);
            r[b] = tx; 
        end 
        #(T_BIT);                          
        if (tx !== 1'b1) begin
            $display("ERROR %0t: stop bit not 1", $time); 
            errors = errors + 1; 
        end
        rx_char[rx_n] = r;                 // store the character
        rx_n = rx_n + 1;                   // one more character
    end

    //LED check: during data byte k of a transfer the LED must be on for k = 0, 2, 4 ... and off for k = 1, 3, 5 ...
    integer dbyte = 0, led_err = 0;
    always @(posedge clk) begin
        if (start && !busy) dbyte = 0;                              //new transfer: count from byte 0
        if (tx_start && tx_data == byte_val) begin                  //a data byte is being sent
            if (led !== (dbyte % 2 == 0)) led_err = led_err + 1;
            dbyte = dbyte + 1;
        end
    end

    task run(input [7:0] bv, input [1:0] sp, input [1:0] cs); // start one transmission and wait for it
        begin
            @(posedge clk);
            byte_val <= bv; speed_sel <= sp; count_sel <= cs; start <= 1'b1; // settings + start pulse
            @(posedge clk); start <= 1'b0;                                   // pulse is one clock long
            @(posedge clk); wait (!busy);                                    // wait until the FSM is back in IDLE
            repeat (2*CPB*10) @(posedge clk);                                // let the receiver finish the last char
        end
    endtask

    task check_square(input integer s, input integer n, input [7:0] bv); // check an N x N square from index s
        integer row, col, k;               // row, column, position in rx_char
        begin
            k = s;                         // start at the first character of this transmission
            for (row = 0; row < n; row = row + 1) begin       // every row:
                for (col = 0; col < n; col = col + 1) begin   //   every column:
                    if (rx_char[k] !== bv) begin
                        errors = errors + 1; 
                        if (errors < 10) 
                        $display("ERROR: char %0d = %02h, expected %02h", k, rx_char[k], bv); 
                        end
                    if (rx_char[k+1] !== 8'h20) begin 
                        errors = errors + 1; 
                        if (errors < 10) 
                        $display("ERROR: char %0d = %02h, expected 20", k+1, rx_char[k+1]); 
                        end
                    k = k + 2;             //     data byte + space
                end
                if (rx_char[k] !== 8'h0D || rx_char[k+1] !== 8'h0A) begin // row must end with CR LF
                    errors = errors + 1; 
                    if (errors < 10) $display("ERROR: row %0d end = %02h %02h, expected 0D 0A", row, rx_char[k], rx_char[k+1]);
                end
                k = k + 2;                 //   CR + LF
            end
            if (rx_n != k) begin 
                $display("ERROR: received %0d chars, expected %0d", rx_n - s, k - s); 
                errors = errors + 1; 
                end // no extra chars
        end
    endtask

    function real gap_clocks(input integer k); // idle clocks on the line before character k
        gap_clocks = (rx_time[k] - (rx_time[k-1] + 10*T_BIT)) / T_CLK; 
    endfunction

    integer s;                             
    real g;                                

    initial begin                          // main test sequence
        $timeformat(-9, 0, " ns", 10);     // print times in ns
        $dumpfile("tb_tx_fsm.vcd"); 
        $dumpvars(0, tb_tx_fsm); 
        repeat (5) @(posedge clk); rst <= 1'b0; repeat (5) @(posedge clk); 

        //test 1 one byte
        s = rx_n;
        run(8'h41, 2'd0, 2'd0);            // byte 41, no delay, N = 1
        $display("Test 1: %0d chars: %02h %02h %02h %02h | rows=%0d bytes=%0d led=%b",
                 rx_n - s, rx_char[s], rx_char[s+1], rx_char[s+2], rx_char[s+3], rows_sent, bytes_sent, led);
        check_square(s, 1, 8'h41);         // expect 41 20 0D 0A
        if (rows_sent != 1 || bytes_sent != 1 || led !== 1'b1) begin $display("ERROR: test 1 counters"); errors = errors + 1; end

        //test 2: 32 x 32, 50 ms, extra start pulse in the middle 
        s = rx_n;
        fork                               // run both branches in parallel:
            run(8'hA5, 2'd1, 2'd1);        //   the transmission
            begin                          //   and, 5000 clocks later, a stray start pulse
                repeat (5000) @(posedge clk);
                start <= 1'b1; @(posedge clk); start <= 1'b0;   // must be ignored
            end
        join                               // continue when both branches are done
        g = gap_clocks(s + 2);             // gap before the second data byte (s = byte, s+1 = space)
        $display("Test 2: %0d chars, rows=%0d bytes=%0d led=%b, inter-byte gap = %0.0f clocks (delay %0d)",
                 rx_n - s, rows_sent, bytes_sent, led, g, D50);
        check_square(s, 32, 8'hA5);
        if (rows_sent != 32 || bytes_sent != 1024 || led !== 1'b0) begin $display("ERROR: test 2 counters"); errors = errors + 1; end
        if (g < D50 || g > D50 + 4) begin $display("ERROR: test 2 delay"); errors = errors + 1; end

        //Test 3: 32 x 32, 200 ms
        s = rx_n;
        run(8'h5A, 2'd3, 2'd1);
        g = gap_clocks(s + 2);
        $display("Test 3: %0d chars, rows=%0d bytes=%0d, inter-byte gap = %0.0f clocks (delay %0d)",
                 rx_n - s, rows_sent, bytes_sent, g, D200);
        check_square(s, 32, 8'h5A);
        if (g < D200 || g > D200 + 4) begin $display("ERROR: test 3 delay"); errors = errors + 1; end

        $display("LED pattern check: %0d data bytes in the last transfer, %0d LED errors", dbyte, led_err);
        if (led_err != 0) errors = errors + led_err;
        if (errors == 0) $display("\n*** tb_tx_fsm PASSED ***\n");          // summary
        else             $display("\n*** tb_tx_fsm FAILED: %0d errors ***\n", errors);
        $finish;                           // end the simulation
    end

endmodule                                  // end of module tb_tx_fsm
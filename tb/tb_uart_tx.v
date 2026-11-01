`timescale 1ns / 1ps

module tb_uart_tx;

    localparam CPB    = 16;                // clocks per bit in simulation (instead of 1736)
    localparam T_CLK  = 10;                // clock period in ns (100 MHz)
    localparam T_BIT  = CPB * T_CLK;       // one bit in ns (160 ns)

    reg clk = 0, tx_start = 0;
    reg rst = 1;
    reg [7:0] tx_data = 8'h00;
    wire tx, tx_busy, tx_done;

    integer errors = 0;
    integer done_count = 0;
    integer rx_count = 0;
    reg [7:0] expected [0:15];
    integer exp_wr = 0;

    always #(T_CLK/2) clk = ~clk;           

    uart_tx #(.CLKS_PER_BIT(CPB)) dut (
        .clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    always@(posedge clk) if (tx_done)       //count every tx_done 
        done_count = done_count + 1;

//reciver model
    reg [7:0] rx_byte;
    integer i;
    real t_fall;
    initial begin
        forever begin
            @(negedge tx);
            t_fall = $realtime;
            #(T_BIT/2);
            if (tx !== 1'b0) begin
                $display("ERROR %0t: start bit not 0", $time);
                errors = errors + 1;
            end
            for (i=0; i<8; i=i+1) begin 
                #(T_BIT);
                rx_byte[i] = tx;
            end
            #(T_BIT);
            if (tx !== 1'b1) begin
                $display("ERROR %0t: stop bit not 1", $time);
                errors = errors + 1;
            end
            if (rx_byte !== expected[rx_count]) begin
                $display("ERROR %0t: got 0x%02h, expected 0x%02h", $time, rx_byte, expected[rx_count]);
                errors = errors + 1;
            end
            else $display ("%0t  RX 0x%02h  OK", $time, rx_byte);
            rx_count = rx_count + 1;
            @(posedge tx_done);
            if ($realtime - t_fall < 10*T_BIT - T_CLK || $realtime - t_fall > 10*T_BIT + 2*T_CLK) begin
                $display ("ERROR: frame took %0.0f ns, expected %0d ns", $realtime - t_fall, 10*T_BIT);
                errors = errors + 1;
            end
        end
    end

//stimulus
    task send (input [7:0] b);          //send byte b through the DUT
        begin
            @(posedge clk);
            while (tx_busy) @(posedge clk);
            expected[exp_wr] = b;
            exp_wr = exp_wr + 1;
            tx_data <= b;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;
        end
    endtask

    initial begin
        $timeformat(-9, 0, " ns", 10);
        $dumpfile ("tb_uart.vcd");
        $dumpvars (0,tb_uart_tx);
        repeat (5) @(posedge clk);
        if (tx !== 1'b1) begin
            $display ("ERROR: line nit idle high after reset");
            errors = errors + 1;
        end
        rst <= 1'b0;                       
        repeat (5) @(posedge clk);         

        send(8'h41);                       // 'A' = 0100_0001
        send(8'hA5);                       // 1010_0101: alternating bits
        send(8'h00);                       // all zeros
        send(8'hFF);                       // all ones

        send(8'h3C);                       
        repeat (3*CPB) @(posedge clk);     
        tx_data <= 8'hEE; tx_start <= 1'b1;
        @(posedge clk);
        tx_start <= 1'b0; 

        wait (!tx_busy);
        repeat (2*CPB) @(posedge clk); 

        if (rx_count != 5) begin 
            $display("ERROR: received %0d bytes, expected 5", rx_count);
            errors = errors + 1; 
            end
        if (done_count != 5) begin
            $display("ERROR: %0d tx_done pulses, expected 5", done_count);
            errors = errors + 1;
            end

        if (errors == 0) $display("\n*** tb_uart_tx PASSED ***\n");         // summary
        else             $display("\n*** tb_uart_tx FAILED: %0d errors ***\n", errors);
        $finish;                           
    end

endmodule                                  



                
                
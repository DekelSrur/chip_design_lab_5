`timescale 1ns / 1ps

module tx_fsm #(
    parameter int DELAY_50MS = 5_000_000,
    parameter int DELAY_100MS = 10_000_000,
    parameter int DELAY_200MS = 20_000_000
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [7:0] byte_val,
    input  logic [1:0] speed_sel,
    input  logic [1:0] count_sel,
    input  logic tx_done,

    output logic tx_start,
    output logic [7:0] tx_data,
    output logic led,
    output logic busy,
    output logic [8:0] rows_sent,
    output logic [16:0] bytes_sent
);
    //State encoding
    typedef enum logic [3:0] {
        IDLE      = 4'b0000,
        SEND_DATA = 4'b0001,
        WAIT_DATA = 4'b0010,
        SEND_SP   = 4'b0011,     //SP = Space
        WAIT_SP   = 4'b0100,
        SEND_CR   = 4'b0101,     //CR = Carriage Return
        WAIT_CR   = 4'b0110,
        SEND_LF   = 4'b0111,     //LF = Line Feed
        WAIT_LF   = 4'b1000,
        DELAY     = 4'b1001
    } state_t;

    state_t curr_st, next;

    logic [7:0] col_cnt;                      //byte position inside the currebt row
    logic [24:0] delay_cnt;     

    logic [8:0] row_len;
    logic [24:0] delay_len;
    logic eol;                               //end of line
    logic last_row;
    logic delay_done;

    //block1 - state register
    always_ff @(posedge clk) begin
        if (rst) curr_st <= IDLE;
        else curr_st <= next;
    end

    //block2 -  next state logic
    always_comb begin
        case (count_sel)
            2'd0: row_len = 9'd1;
            2'd1: row_len = 9'd32;
            2'd2: row_len = 9'd128;
            default: row_len = 9'd256;
        endcase

        case (speed_sel)
            2'd1: delay_len = 25'(DELAY_50MS);
            2'd2: delay_len = 25'(DELAY_100MS);
            default: delay_len = 25'(DELAY_200MS);
        endcase

        eol = ({1'b0,col_cnt} == row_len - 1'b1);
        last_row = (rows_sent == row_len - 1'b1);
        delay_done = (speed_sel == 2'd0) || (delay_cnt == delay_len - 1'b1);

    //next state
        next = curr_st;
        case (curr_st)
            IDLE: if(start) next = SEND_DATA;
            SEND_DATA: next = WAIT_DATA;
            WAIT_DATA: if(tx_done) next = SEND_SP;
            SEND_SP: next = WAIT_SP;
            WAIT_SP: if(tx_done) begin
                if (eol) next = SEND_CR;
                else next = DELAY;
            end
            SEND_CR: next = WAIT_CR;
            WAIT_CR: if(tx_done) next = SEND_LF;
            SEND_LF: next = WAIT_LF;
            WAIT_LF: if(tx_done) begin
                if (last_row) next = IDLE;
                else next = DELAY;
            end
            DELAY: if (delay_done) next = SEND_DATA;
            default: next = IDLE;
        endcase
    end

    //block3 - registered outputs
    always_ff @(posedge clk) begin
        if (rst) begin
            tx_start <= 1'b0;
            tx_data <= 8'h00;
            busy <= 1'b0;
            led <= 1'b0;
            col_cnt <= 8'd0;
            rows_sent <= 9'd0;
            bytes_sent <= 17'd0;
            delay_cnt <= 25'd0;
        end

        else begin                          //moore outputs
            busy <= (next != IDLE);
            case (next)
                SEND_DATA: begin            //send data byte
                    tx_start <= 1'b1;
                    tx_data <= byte_val;
                    led <= (curr_st == IDLE) ? 1'b1 : ~led;   //byte 0 -> on, byte 1 -> off, byte 2 -> on ...
                end

                SEND_SP: begin              //data space
                    tx_start <= 1'b1;
                    tx_data <= 8'h20;
                end

                SEND_CR: begin              //send carriage return
                    tx_start <= 1'b1;
                    tx_data <= 8'h0D;
                end

                SEND_LF: begin              //send feed finished
                    tx_start <= 1'b1;
                    tx_data <= 8'h0A;
                end 

                default: tx_start <= 1'b0;                   
            endcase

            delay_cnt <= (curr_st == DELAY) ? delay_cnt + 1'b1 : 25'd0;

            if (curr_st == IDLE && start) begin         //new transmition starts 
                col_cnt <= 8'd0;
                rows_sent <= 9'd0;
                bytes_sent <= 17'd0;
            end

            if (curr_st == WAIT_DATA && tx_done) begin  //data byte finished
                bytes_sent <= bytes_sent + 1'b1;
            end

            if (curr_st == WAIT_SP && tx_done && !eol)  //space finished
                col_cnt <= col_cnt + 1'b1;

            if (curr_st == WAIT_LF && tx_done) begin    //line feed finished
                rows_sent <= rows_sent + 1'b1;
                col_cnt <= 8'd0;
            end        
        end
    end

endmodule

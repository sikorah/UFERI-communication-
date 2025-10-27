`timescale 1ns/1ps

module sreg_ctrl (
    input logic clk,
    input logic rst_n,
    input logic [41:0] data_in,

    output logic ready,
    output logic shift,
    output logic sclk,
    output logic [41:0] data_out
);

typedef enum {IDLE, LOAD_SREG, READ_SREG} op_type_t;

op_type_t state;

logic [5:0] shift_cnt;
logic [1:0] clk_div;

always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n) begin
        state <= IDLE;
        data_out <= 42'd0;
        clk_div <= 2'd0;
        sclk <= 1'b0;
        ready <= 1'b1;
        shift <= 1'b0;
        shift_cnt <= 6'd0;
    end else begin
        clk_div <= clk_div + 2'd1;
        sclk <= clk_div[1];

        ready <= 1'b0;
        shift <= 1'b0;

        case (state)
            IDLE: begin
                shift_cnt <= 6'd0;
                if (ready) begin
                    state <= LOAD_SREG;
                end else begin
                    state <= IDLE;
                end
            end
            LOAD_SREG: begin
                data_out <= data_in;
                state <= READ_SREG;
            end
            READ_SREG: begin
                shift <= 1'b1;

                data_out <= {1'b0, data_out[41:1]};

                if(shift_cnt == 6'd41) begin
                    state <= IDLE;
                    shift_cnt <= 6'd0;
                end else begin
                    shift_cnt <= shift_cnt + 6'd1;
                    state <= READ_SREG;
                end
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
end



endmodule

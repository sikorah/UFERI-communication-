`timescale 1ns/1ps

module sreg_ctrl (
    input logic clk,
    input logic rst_n,
    input logic [41:0] data_in,
    input logic [1:0] sreg_in,

    output logic ready,
    output logic shift,
    output logic [41:0] data_out
);

typedef enum {IDLE, LOAD_SREG, READ_SREG} op_type_t;

op_type_t state;

logic [5:0] shift_cnt;

always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n) begin
        ready <= '0;
        shift <= '0;
        data_out <= '0;
    end else begin
        case (state)
            IDLE: begin
                if(ready) begin
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
                shift = 1'b1;
                if (shift_cnt == 6'd41) begin
                    shift_cnt <= 6'd0;
                    state <= IDLE;
                end else begin
                    shift_cnt = shift_cnt + 1;
                    state <= READ_SREG;
                end
            end 
        endcase
    end
end



endmodule

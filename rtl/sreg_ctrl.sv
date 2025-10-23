`timescale 1ns/1ps

module sreg_ctrl (
    input logic sclk,
    input logic rst_n,
    input logic [41:0] data_in,

    output logic ready,
    output logic [41:0] data_out
);

typedef enum {IDLE, LOAD_SREG, READ_SREG} op_type_t;

op_type_t state;

always_ff @(posedge sclk) begin
    if (!rst_n) begin
        ready <= 1'b0;
        data_out <= 42'd0;
        state <= IDLE;
    end else begin
        case(state)
            IDLE: begin
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
                data_out <= {2'b00, data_out[41:2]};
                state <= IDLE;
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
end



endmodule

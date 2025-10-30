`timescale 1ns/1ps

module sreg_ctrl (
    input logic clk,
    input logic rst_n,


    input logic cmd_valid,
    input logic [2:0] cmd,
    input logic [41:0] data_in,

    output logic [41:0] data_out,
    output logic cmd_ready,

    // porty do IC
    input logic [1:0] sreg_in,

    output logic shift,
    output logic sclk,
    output logic serial_out,
    output logic write_cfg,
);

typedef enum {IDLE, LOAD_SREG, READ_SREG} op_type_t;

op_type_t state;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        shift <= '0;
        data_out <= '0;
        sclk <= '0;
        serial_out <= '0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                sclk <= sclk;
                shift <= shift;
                if (cmd_valid && cmd_ready) begin
                    cmd_ready <= '0;
                    case(cmd) 
                       0: begin
                        state <= READ_SREG;
                       end 
                       1: begin
                        state <= LOAD_SREG;
                       end
                    endcase
                end else begin
                    cmd_ready <= '1;
                    state <= IDLE;
                end
            end
            LOAD_SREG: begin
                sclk <= ~sclk;
                shift <= '1;
                if (ready) begin
                    serial_out <= data_in[41];
                    data_in <= data_in << 1;
                    state <= READ_SREG;
                end else begin
                    state <= IDLE;
                end
            end
            READ_SREG: begin
                sclk <= ~sclk;
                shift <= '1;
                if (ready) begin
                    data_out[41:21] <= {'0, sreg_in[0]};
                    data_out[20:0] <= {'0, sreg_in[1]};
                    state <= LOAD_SREG;
                end else begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule

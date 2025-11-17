`timescale 1ns/1ps

module sreg_ctrl (
    input logic clk,
    input logic rst_n,

    // porty do FSM
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
    output logic write_cfg
);

reg [41:0]  data_int;

// liczniki 
logic [6:0] counter_int;
logic [6:0] counter_limit;

typedef enum {IDLE, LOAD_SREG, READ_SREG} op_type_t;
op_type_t state;

typedef enum logic [2:0] {
    PIX_WRITE          = 3'b000,
    PIX_READ           = 3'b001,
    PIX_READ_END       = 3'b010,
    WRITE_PCLK_0       = 3'b011,
    WRITE_PCLK_1       = 3'b100,
    WRITE_FULL_PCLK_0  = 3'b101,
    WRITE_FULL_PCLK_1  = 3'b110,
    SREG_READ          = 3'b111
} cmd_opcode_t;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        data_out <= 42'b0;
        cmd_ready <= 1'b0;
        shift <= 1'b0;
        sclk <= 1'b1;
        serial_out <= 1'b0;
        write_cfg <= 1'b0;
        counter_int <= 7'b0;
        counter_limit <= 7'b0;
        state <= IDLE;
    end else begin
        data_int <= data_in;
        case (state)
            IDLE: begin
                sclk <= sclk;
                shift <= shift;
                counter_limit <= 7'b0;
                if (cmd_valid && cmd_ready) begin
                    cmd_ready <= 1'b0;
                    case(cmd)
                        PIX_WRITE: begin
                            counter_limit <= 7'd84;
                            state <= LOAD_SREG;
                        end
                        PIX_READ: begin
                            counter_limit <= 7'd42;
                            state <= READ_SREG;
                        end
                        PIX_READ_END: begin
                            counter_limit <= 7'd6;
                            state <= READ_SREG;
                        end
                        WRITE_PCLK_0: begin
                            counter_limit <= 7'd20;
                            state <= LOAD_SREG;
                        end
                        WRITE_PCLK_1: begin
                            counter_limit <= 7'd20;
                            state <= LOAD_SREG;
                        end
                        WRITE_FULL_PCLK_0: begin
                            counter_limit <= 7'd84;
                            state <= LOAD_SREG;
                        end
                        WRITE_FULL_PCLK_1: begin
                            counter_limit <= 7'd84;
                            state <= LOAD_SREG;
                        end
                        SREG_READ: begin
                            counter_limit <= 7'd46;
                            state <= READ_SREG;
                        end
                        default: begin
                            state <= IDLE;
                        end
                    endcase
                end else begin 
                    cmd_ready <= 1'b1;
                    state <= IDLE;
                end
            end
            LOAD_SREG: begin 
                sclk <= ~sclk;
                case(cmd)
                    PIX_WRITE: begin
                        shift <= 1'b1;
                        write_cfg <= 1'b0;
                        //dvalid_out <= 1'b0;
                        if (counter_int < counter_limit) begin
                            serial_out <= data_int[41];
                            data_int <= data_int << 1;
                            counter_int <= counter_int + 1;
                            state <= LOAD_SREG;
                        end else begin
                            shift <= 1'b0;
                            write_cfg <= 1'b0;
                            counter_int <= 7'b0;
                            state <= IDLE;
                        end
                    end
                    WRITE_PCLK_0: begin
                        shift <= 1'b1;
                        //dvalid_out <= 1'b0;
                        if (counter_int < counter_limit) begin
                            serial_out <= data_int[41];
                            data_int <= data_int << 1;
                            counter_int <= counter_int + 1;
                            state <= LOAD_SREG;
                        end else if(counter_int == 18) begin
                            write_cfg <= 1'b1;
                            state <= LOAD_SREG;
                        end else begin
                            shift <= 1'b0;
                            write_cfg <= 1'b0;
                            counter_int <= 7'b0;
                            state <= IDLE;
                        end
                    end
                    WRITE_PCLK_1: begin
                        shift <= 1'b1;
                        //dvalid_out <= 1'b0;
                        if (counter_int < counter_limit) begin
                            serial_out <= data_int[41];
                            data_int <= data_int << 1;
                            counter_int <= counter_int + 1;
                            state <= LOAD_SREG;
                        end else if(counter_int == 18) begin
                            write_cfg <= 1'b1;
                            state <= LOAD_SREG;
                        end else begin
                            shift <= 1'b0;
                            write_cfg <= 1'b0;
                            counter_int <= 7'b0;
                            state <= IDLE;
                        end
                    end
                    WRITE_FULL_PCLK_0: begin
                        shift <= 1'b1;
                        //dvalid_out <= 1'b0;
                        if (counter_int < counter_limit) begin
                            serial_out <= data_int[41];
                            data_int <= data_int << 1;
                            counter_int <= counter_int + 1;
                            state <= LOAD_SREG;
                        end else if(counter_int == 82) begin
                            write_cfg <= 1'b1;
                            state <= LOAD_SREG;
                        end else begin
                            shift <= 1'b0;
                            write_cfg <= 1'b0;
                            counter_int <= 7'b0;
                            state <= IDLE;
                        end
                    end
                    WRITE_FULL_PCLK_1: begin
                        shift <= 1'b1;
                        //dvalid_out <= 1'b0;
                        if (counter_int < counter_limit) begin
                            serial_out <= data_int[41];
                            data_int <= data_int << 1;
                            counter_int <= counter_int + 1;
                            state <= LOAD_SREG;
                        end else if(counter_int == 82) begin
                            write_cfg <= 1'b1;
                            state <= LOAD_SREG;
                        end else begin
                            shift <= 1'b0;
                            write_cfg <= 1'b0;
                            counter_int <= 7'b0;
                            state <= IDLE;
                        end
                    end
                endcase
            end
            READ_SREG: begin 
                sclk <= ~sclk;
                case(cmd)
                    PIX_READ: begin
                        write_cfg <= 1'b0;
                        //dvalid_out <= 1'b1;
                        if (counter_int < counter_limit) begin
                            data_out[41:21] <= {'0, sreg_in[0]};
                            data_out[20:0] <= {'0, sreg_in[1]};
                            counter_int <= counter_int + 1;
                            state <= READ_SREG;
                        end else if (counter_int == 2) begin
                            shift <= 1'b1;
                        end else begin
                            shift <= 1'b0;
                            counter_int <= 7'b0;
                            state <= IDLE;
                        end
                    end
                    PIX_READ_END: begin
                        write_cfg <= 1'b0;
                        //dvalid_out <= 1'b0;
                        if (counter_int < counter_limit) begin
                            shift <= 1'b1;
                            counter_int <= counter_int + 1;
                            state <= READ_SREG;
                        end else begin
                            shift <= 1'b0;
                            counter_int <= 7'b0;
                            state <= IDLE;
                        end
                    end
                    SREG_READ: begin
                        shift <= 1'b1;
                        write_cfg <= 1'b0;
                        if (counter_int < counter_limit) begin
                            data_out[41:21] <= {'0, sreg_in[0]};
                            data_out[20:0] <= {'0, sreg_in[1]};
                            counter_int <= counter_int + 1;
                            state <= READ_SREG;
                        //end else if (counter_int > 0 && counter_int < 42) begin
                            //dvalid_out <= 1'b1;
                        end else begin
                            shift <= 1'b0;
                            counter_int <= 7'b0;
                            state <= IDLE;
                        end
                    end
                endcase
            end
        endcase
    end
end 

endmodule

module uart #(
    localparam int BAUD = 4
)(
    input logic         clk,
    input logic         rst_n,

    input logic         rx_din,
    input logic         rx_vin,

    output logic [3:0]  rx_dout,
    output logic        rx_vout
);

typedef enum {RX_READY, RX_DATA, RX_STOP} state;

state rx_state;

logic [3:0] baud_cnt;
logic [9:0] rx_buf;
logic       rx_done;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        rx_state <= RX_READY;
        baud_cnt <= '0;
        rx_done <= 1'b0;
    end else begin 
        rx_buf        <= rx_buf;
        baud_cnt      <= baud_cnt;
        rx_done       <= 1'b0;
        rx_state      <= rx_state;

        if (rx_vin) begin
            rx_buf <= {rx_din, rx_buf[9:1]};
            case (rx_state)
                RX_READY: begin
                    rx_state <= RX_DATA;
                end
                RX_DATA: begin
                    if (baud_cnt == BAUD-1) begin
                        baud_cnt <= '0;
                        rx_state <= RX_STOP;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end
                RX_STOP: begin
                    rx_done  <= 1'b1;
                    rx_state <= RX_READY;
                end
                default: begin
                    baud_cnt <= '0;
                    rx_state <= RX_READY;
                end
            endcase
        end
    end
end

assign rx_dout = rx_buf[BAUD:1];
assign rx_vout = rx_done;

endmodule
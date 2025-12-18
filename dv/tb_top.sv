`timescale 1ns/1ps

module tb_top;
// sygnały kontrolera
logic clk;
logic rst_n;
logic cmd_valid;
logic [2:0] cmd;
logic [41:0] data_in;
logic [41:0] data_out;
logic cmd_ready;
logic [1:0] sreg_in;
logic shift;
logic sclk;
logic serial_out;
logic write_cfg;
logic pclk;
logic dvalid_out;

// sygnały modelu
logic serial_in;
logic [41:0] pixel_in;
logic [1:0] sreg_out;
logic [41:0] cfg_out;

// sygnały UART
logic rx_din;
logic rx_vin;
logic [7:0] rx_dout;
logic rx_vout;

sreg_ctrl u_sreg_ctrl(
    .clk        (clk),
    .rst_n      (rst_n),
    .cmd_valid  (cmd_valid),
    .cmd        (cmd),
    .data_in    (data_in),
    .data_out   (data_out),
    .cmd_ready  (cmd_ready),
    .sreg_in    (sreg_in),
    .shift      (shift),
    .sclk       (sclk),
    .serial_out (serial_out),
    .write_cfg  (write_cfg),
    .pclk       (pclk),
    .dvalid_out ()
);
    
sreg_model u_sreg_model(
    .sclk       (sclk),
    .shift      (shift),
    .serial_in  (serial_out),
    .write_cfg  (write_cfg),
    .pixel_in   (),
    .sreg_out   (sreg_in),
    .cfg_out    ()
);

/*FSM u_FSM(
    .clk(clk),
    .rst_n(rst_n),
    .cmd_ready(cmd_ready),
    .cmd_valid(cmd_valid),
    .cmd(cmd),
    .data_in(data_in)
);*/

uart u_uart(
    BAUD = 8
)(
    .clk        (clk),
    .rst_n      (rst_n),
    .rx_din     (),
    .rx_vin     (),
    .rx_dout    (cmd),
    .rx_vout    ()
);

// generacja zegara i resetu

initial begin
    clk = '0;

    forever begin
        #2.5 clk = ~clk;
    end
end

initial begin
    rst_n = '0;
    repeat(2)
        @(posedge clk);

    rst_n = '1;
end

task test_control(input logic[2:0] command, input logic [41:0] test_data);

    @(posedge clk);

    cmd_valid <= '1;
    cmd <= command;
    data_in <= test_data;
    @(posedge clk);

    while(cmd_ready == 1'b0)
        @(posedge clk);
    //comand latched
    cmd_valid <= '0;
    @(posedge clk);
    while(cmd_ready == 1'b0)
        @(posedge clk);
    //command executed
endtask

initial begin
    logic [41:0] test_data1 = 42'b10_0110_1011_0100_1011_0101_1111_0110_1001_0010_1011;
    logic [41:0] test_data2 = ~(42'b10_0110_1011_0110_1011_0100_1111_0110_1001_0010_1011);

    repeat(2)
        @(posedge clk);

    test_control(3'b000, test_data1); //PIX_WRITE

    repeat(2)
        @(posedge clk);

    test_control(3'b001, '0); //PIX_READ

    repeat(2)
        @(posedge clk);

    test_control(3'b010, '0); //PIX_READ_END

    repeat(2)
        @(posedge clk);

    test_control(3'b011, test_data1); //WRITE_PCLK_0

    repeat(2)
        @(posedge clk);

    test_control(3'b100, test_data2); //WRITE_PCLK_1

    repeat(2)
        @(posedge clk);

    test_control(3'b101, test_data1); //WRITE_FULL_PCLK_0

    repeat(2)
        @(posedge clk);

    test_control(3'b110, test_data2); //WRITE_FULL_PCLK_1

    repeat(2)
        @(posedge clk);

    test_control(3'b111, '0); //SREG_READ

    repeat(2)
        @(posedge clk);

    $finish;
end

endmodule
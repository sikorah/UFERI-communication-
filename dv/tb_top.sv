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

logic [3:0] wdata;
logic wr_en;
logic full;
logic [3:0] fifo;
logic rd_en;
logic empty;


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


FSM u_FSM(
    .clk(clk),
    .rst_n(rst_n),
    .cmd_ready(cmd_ready),
    .cmd_valid(cmd_valid),
    .cmd(cmd),
    .fifo_in(fifo),
    .data2ctrl(data_in)
);

uart u_uart(
    .clk        (clk),
    .rst_n      (rst_n),
    .rx_din     (rx_din),
    .rx_vin     (rx_vin),
    .rx_dout    (wdata),
    .rx_vout    (wr_en)
);

FIFO u_FIFO(
    .clk (clk),
    .rst_n (rst_n),
    .wdata (wdata),
    .wr_en (wr_en),
    .full (full),
    .rdata (fifo),
    .rd_en (rd_en),
    .empty (empty)
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

task test_sequence(input logic[3:0] uart);
    
    @(posedge clk);

    //cmd_ready <= '1;
    fifo <= uart;
    @(posedge clk);

    while(cmd_valid == 1'b0)
        @(posedge clk);
    //command latched
    //cmd_ready <= '0;
    @(posedge clk);
    while(cmd_valid == 1'b0)
        @(posedge clk);
endtask

task write_sreg(input logic [41:0] test_data);

    @(posedge clk);
    sclk <= '1;
    for (int i = 0; i<84; ++i) begin
        @(posedge clk);
        sclk <= ~sclk;
        if(sclk == 1) begin
            shift <= '1;
            serial_in <= test_data[41];
            test_data <= test_data << 1;
        end
    end

endtask

task write_config(input logic [41:0] test_data);

    @(posedge clk);
    sclk <= '1;
    for (int i = 0; i<84; ++i) begin
        @(posedge clk);
        sclk <= ~sclk;
        if(sclk == 1) begin
            shift <= '1;
            serial_in <= test_data[41];
            test_data <= test_data << 1;
            write_cfg <= i == 82 ? 1'b1 : 1'b0;
        end
    end
    @(posedge clk);
    write_cfg <= 0;

endtask

task test_uart(input logic [3:0] data);

    @(posedge clk);
    rx_vin <= 1'b1;
    rx_din <= data[3];
    @(posedge clk);
    rx_din <= data[2];
    @(posedge clk);
    rx_din <= data[1];
    @(posedge clk);
    rx_din <= data[0];
    @(posedge clk);
    rx_vin <= 1'b0;

endtask


initial begin

    repeat(5)
        @(posedge clk);

    test_uart(4'b0110);

    

    test_uart(4'b1001);

    

    test_uart(4'b0001);

    

    test_uart(4'b0011);

    

    test_uart(4'b1101);

    

    test_uart(4'b1011);


    $finish;
end

endmodule
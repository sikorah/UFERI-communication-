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

// sygnały modelu
logic serial_in;
logic [41:0] pixel_in;
logic [1:0] sreg_out;
logic [41:0] cfg_out;

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
    .write_cfg  (write_cfg)
);
    
sreg_model u_sreg_model(
    .sclk       (),
    .shift      (),
    .serial_in  (),
    .write_cfg  (),
    .pixel_in   (),
    .sreg_out   (),
    .cfg_out    ()
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
    repeat (84)
        @(posedge clk);

    rst_n = '0;
end

/*task send_command(input logic [2:0] command, input logic [41:0] test_data);
    @(posedge clk);
    sclk <= '1;
    cmd <= command;
    for (int i = 0; i<84; ++i) begin
        @(posedge clk);
        sclk <= ~sclk;
        if(sclk == 1) begin
            shift <= '1;
            serial_in <= test_data[41];
            test_data <= test_data << 1;
        end
    shift <= '0;
    end

endtask*/

task test_control(input logic[2:0] command, input logic [41:0] test_data);
    shift <= '0;
    serial_out <= '0;
    sreg_in <= '0;
    sclk <= '1;
    cmd_valid <= '1;

    @(posedge clk);

    cmd <= command;
    data_in <= test_data;

    repeat(42)
        @(posedge clk);
endtask

initial begin
    logic [41:0] test_data1 = 42'b10_0110_1011_0100_1011_0101_1111_0110_1001_0010_1011;
    logic [41:0] test_data2 = ~(42'b10_0110_1011_0110_1011_0100_1111_0110_1001_0010_1011);

    shift <= '0;
    serial_out <= '0;
    sreg_in <= '0;
    sclk <= '1;
    cmd_valid <= '1;

    repeat(4)
        @(posedge clk);

    test_control(3'b000, test_data1); //PIX_WRITE

    repeat(2);
        @(posedge clk);

    test_control(3'b001, '0); //PIX_READ

    repeat(2);
        @(posedge clk);

    test_control(3'b011, test_data1); //WRITE_PCLK_0

    repeat(2);
        @(posedge clk);

    test_control(3'b111, '0); //SREG_READ

    repeat(2);
        @(posedge clk);

    /*repeat (2)
        @(posedge clk);

    send_command(3'b000, test_data1); // PIX_WRITE
    repeat (2)
        @(posedge clk);

    send_command(3'b001, '0); // PIX_READ
    repeat (2)
        @(posedge clk);

    send_command(3'b010, '0); // PIX_READ_END
    repeat (2)
        @(posedge clk);

    send_command(3'b011, test_data1); // WRITE_PCLK_0
    repeat (2)
        @(posedge clk);

    send_command(3'b100, test_data1); // WRITE_PCLK_1
    repeat (2)
        @(posedge clk);

    send_command(3'b101, test_data1); // WRITE_FULL_PCLK_0
    repeat (2)
        @(posedge clk);

    send_command(3'b110, test_data1); // WRITE_FULL_PCLK_1
    repeat (2)
        @(posedge clk);

    send_command(3'b111, '0); // SREG_READ
    repeat (2)
        @(posedge clk);*/

    shift <= '0;
    serial_out <= '0;
    sreg_in <= '1;
    sclk <= '1;
    cmd_valid <= '1;
    $finish;
end

endmodule
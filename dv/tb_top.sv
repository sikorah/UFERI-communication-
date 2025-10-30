`timescale 1ns/1ps

module tb_top();
logic clk;
logic sclk;
logic rst_n;
logic shift;
//logic ready;

logic serial_in;
logic [41:0] pixel_in;
//logic [41:0] data_in;
//logic [1:0] sreg_in;

//logic serial_out;
logic [1:0] sreg_out;
//logic [41:0] data_out;

logic write_cfg;
logic [41:0] cfg_out;

sreg_model u_sreg_model(
    .sclk,
    .shift,
    .serial_in,
    .pixel_in,
    .sreg_out,
    .write_cfg,
    .cfg_out
);

/*sreg_ctrl u_sreg_ctrl(
    .clk,
    .rst_n,
    .data_in,
    .sreg_in(sreg_out),
    .ready,
    .shift(shift),
    .sclk(sclk),
    .serial_out(serial_in),
    .data_out
);*/

initial begin
    clk = '0;

    forever begin
        #2.5 clk = ~clk;
    end
end

initial begin
    rst_n = '0;

    repeat (84)
        @(posedge clk);

    rst_n = '1;
end

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

 /*   pixel_in <= test_data;
    @(posedge clk);

    shift <= '1;
    repeat(21) begin
        @(posedge clk);
    end

    shift <= '0;
    pixel_in <= 42'b0;
    @(posedge clk);

    // SIPO Test
    shift <= '1;
    repeat(42) begin
        serial_in <= test_data[41:40];
        test_data <= test_data << 1;
        @(posedge clk);
    end
    shift <= '0;*/
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

/*task test_sreg_control();
    logic [41:0] test_data = 42'b10_0110_1011_0100_1011_0101_1111_0110_1001_0010_1011;
    ready <= '0;

    data_in <= test_data;
    @(posedge clk);

    ready <= '1;
    repeat(42) begin
        @(posedge clk);
    end

    ready <= '0;
endtask*/

initial begin
    logic [41:0] test_data1 = 42'b10_0110_1011_0100_1011_0101_1111_0110_1001_0010_1011;
    logic [41:0] test_data2 = ~(42'b10_0110_1011_0110_1011_0100_1111_0110_1001_0010_1011);
    shift <= '0;
    serial_in <= '0;
    sclk <= '1;
    
    repeat (4)
        @(posedge clk);

    write_sreg(test_data1);
    write_config(test_data2);

    repeat (4)
        @(posedge clk);

    shift <= '0;
    serial_in <= '0;
    sclk <= '1;
    $finish;

end

endmodule
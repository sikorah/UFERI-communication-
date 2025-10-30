`timescale 1ns/1ps

module tb_top();
logic clk;
//logic sclk;
logic rst_n;
logic shift;
//logic ready;

logic serial_in;
logic [41:0] pixel_in;
//logic [41:0] data_in;
//logic [1:0] sreg_in;

logic [1:0] sreg_out;
//logic [41:0] data_out;

/*sreg_ctrl u_sreg_ctrl(
    .clk,
    .rst_n,
    .data_in,
    .sreg_in,
    .ready,
    .shift,
    .sclk,
    .data_out
);*/

sreg_model u_sreg_model(
    .sclk(clk),
    .shift,
    .serial_in,
    .pixel_in,
    .sreg_out
);

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

task test_sreg_model();

    // PISO Test
    logic [41:0] test_data = 42'b10_0110_1011_0100_1011_0101_1111_0110_1001_0010_1011;
    shift <= '0;                                        // ^ [20]

    pixel_in <= test_data;
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
    shift <= '0;
endtask

/*task test_sreg_control();
    logic [41:0] test_data = 42'b10_0110_1011_0100_1011_0100_1111_0110_1001_0010_1010;
    shift <= '0;
    ready <= '0;

    data_in <= test_data;
    @(posedge clk);

    ready <= '1;
    repeat(42) begin
        @(posedge clk);
    end

    shift <= '0;
    ready <= '0;
endtask*/

initial begin
    shift <= '0;
    serial_in <= '0;
    //ready <= '0;
    
    repeat (4)
        @(posedge clk);

    test_sreg_model();

    repeat (4)
        @(posedge clk);

    shift <= '0;
    serial_in <= '0;
    //ready <= '0;
    $finish;

end

endmodule
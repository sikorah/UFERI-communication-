`timescale 1ns/1ps

module tb_top();
logic clk;
logic rst_n;
logic [41:0] data_in;
logic ready;
logic load;
logic shift;
logic [41:0] pix_in;
logic [41:0] data_out;
logic [1:0] sreg_out;


sreg_model u_sreg_model(
    .sclk(clk),
    .rst_n,
    .shift,
    .load,
    .pix_in,
    .sreg_out
);

sreg_ctrl u_sreg_ctrl(
    .sclk(clk),
    .rst_n,
    .data_in,
    .ready,
    .data_out
);

initial begin
    clk = '0;

    forever begin
        #10 clk = ~clk;
    end
end

initial begin
    rst_n = '0;

    repeat (2)
        @(posedge clk);

    rst_n = '1;
end

task test();
    logic [41:0] data = 42'hFFFF_FFFF_FFFF;
    ready = '0;
    shift = '0;

    ready = '1;
    @(posedge clk);

    data_in <= data;
    @(posedge clk);

    repeat(21) begin
        shift = '1;
        @(posedge clk);
    end

    ready = '0;
    shift = '0;
endtask

initial begin
    ready = '0;
    shift = '0;

    repeat (4)
        @(posedge clk);
    test();
    repeat (4)
        @(posedge clk);

    $finish;
end

endmodule
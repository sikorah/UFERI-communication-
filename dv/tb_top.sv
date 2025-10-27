`timescale 1ns/1ps

module tb_top();
logic sclk;
logic rst_n;
logic shift;
logic serial_in;
logic [41:0] pixel_in;
logic [1:0] sreg_out;

sreg_model u_sreg_model(
    .sclk,
    .shift,
    .serial_in,
    .pixel_in,
    .sreg_out
);


initial begin
    sclk = '0;

    forever begin
        #2.5 sclk = ~sclk;
    end
end

initial begin
    rst_n = '0;

    repeat (42)
        @(posedge sclk);

    rst_n = '1;
end

task test_sreg_model();
    logic [41:0] test_data = 42'hAAA_BBBB_CCCC;
    shift <= '0;

    pixel_in <= test_data;
    @(posedge sclk);

    shift <= '1;
    repeat(42) begin
        @(posedge sclk);
    end

    shift <= '0;
endtask

initial begin
    shift <= '0;
    
    repeat (8)
        @(posedge sclk);

    test_sreg_model();

    repeat (8)
        @(posedge sclk);

    $finish;

end

endmodule
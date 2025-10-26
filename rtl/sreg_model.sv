`timescale 1ns / 1ps

module sreg_model(
    input logic sclk,
    input logic rst_n,
    input logic shift,
    input logic load,
    input logic serial_in,
    input logic [41:0] pixel_in,

    output logic [1:0] sreg_out
);

logic [41:0] sreg, next_sreg;

always_comb begin
    next_sreg = sreg;
    if (load) begin
        next_sreg = pixel_in;
    end else if (shift) begin
        next_sreg = {sdin, sreg[41:1]};
    end
end

always_ff @(posedge sclk or negedge rst_n) begin
    if (!rst_n) begin
        sreg <= 42'd0;
        sreg_out <= 2'b00;
    end else begin
        sreg <= next_sreg;
        sreg_out <= next_sreg[20];
        sreg_out <= next_sreg[41];
    end
end



endmodule

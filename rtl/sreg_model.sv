`timescale 1ns / 1ps

module sreg_model(
    input logic sclk,
    input logic rst_n,
    input logic shift,
    input logic load,
    input logic [41:0] pix_in,

    output logic [1:0] sreg_out
);

logic [41:0] sreg;

always_ff @(posedge sclk) begin
    if (!rst_n) begin
        sreg_out <= 2'b00;
        sreg <= 42'd0;
    end else if (load)begin
        sreg <= pix_in;

    end else if (shift) begin
        sreg <= {2'b00, sreg[41:2]};
    end else begin
        sreg_out <= sreg[1:0];
    end
end


endmodule

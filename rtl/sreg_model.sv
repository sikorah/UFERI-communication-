`timescale 1ns / 1ps

module sreg_model(
    input logic sclk,
    input logic shift,
    input logic serial_in,
    input logic [41:0] pixel_in,

    output reg [1:0] sreg_out
);

reg [41:0] sreg_int;

always_ff @(posedge sclk) begin
    if (shift) begin
        sreg_out[1] <= sreg_int[20];
        sreg_out[0] <= sreg_int[41];
        sreg_int <= {sreg_int[41:0], 1'b0};
    end else begin
        sreg_int <= pixel_in;
    end
end

endmodule

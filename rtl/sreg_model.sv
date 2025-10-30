`timescale 1ns / 1ps

module sreg_model(
    input logic sclk,
    input logic shift,
    input logic serial_in,
    input logic write_cfg,
    input reg [41:0] pixel_in,

    output reg [1:0] sreg_out,
    output reg [41:0] cfg_out
);

reg [41:0] sreg_int;

always_ff @(posedge sclk) begin
    if (shift) begin
        sreg_int[41:0] <= {sreg_int[40:0], serial_in};
    end else begin
        sreg_int <= pixel_in;
    end
end

assign sreg_out[1] = sreg_int[41];
assign sreg_out[0] = sreg_int[20];

always_ff @(posedge sclk) begin
    if (write_cfg) begin
        cfg_out[41:0] <= {sreg_int[40:0], serial_in};
    end
end

endmodule

module FIFO #(
    parameter WIDTH = 4,
    parameter DEPTH = 8 // 1024 - 2^14
)(
    input  logic             clk,
    input  logic             rst_n,

    input  logic [WIDTH-1:0] wdata,
    input  logic             wr_en,
    output logic             full,

    output logic [WIDTH-1:0] rdata,
    input  logic             rd_en,
    output logic             empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);
    logic [ADDR_WIDTH-1:0] rptr, wptr;
    logic last_was_read;
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wptr] <= wdata;
                wptr      <= wptr + 1'b1;
            end
        end
    end 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rptr <= 0;
        end else begin
            if (rd_en && !empty) begin
                rptr    <= rptr + 1'b1;
                rdata <= mem[rptr];
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_was_read <= 1; // Initialize as empty
        end else begin
            if (rd_en && !empty) begin
                last_was_read <= 1;
            end else if (wr_en && !full) begin
                last_was_read <= 0;
            end else begin
                last_was_read <= last_was_read;
            end
        end
    end

    assign full    = (wptr == rptr) && !last_was_read;
    assign empty   = (wptr == rptr) &&  last_was_read;
    
endmodule
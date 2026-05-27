module async_fifo #(
    parameter int DATA_WIDTH = 18,
    parameter int ADDR_WIDTH = 10
) (
    input  logic                  wr_clk,
    input  logic                  wr_reset,
    input  logic                  wr_valid,
    output logic                  wr_ready,
    input  logic [DATA_WIDTH-1:0] wr_data,

    input  logic                  rd_clk,
    input  logic                  rd_reset,
    output logic                  rd_valid,
    input  logic                  rd_ready,
    output logic [DATA_WIDTH-1:0] rd_data,

    output logic                  wr_full,
    output logic                  rd_empty,
    output logic [ADDR_WIDTH:0]   wr_level,
    output logic [ADDR_WIDTH:0]   rd_level
);

    localparam int PTR_WIDTH = ADDR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];

    logic [PTR_WIDTH-1:0] wr_bin, wr_gray, wr_gray_plus_one;
    logic [PTR_WIDTH-1:0] rd_bin, rd_gray;
    logic [PTR_WIDTH-1:0] rd_gray_wr1, rd_gray_wr2;
    logic [PTR_WIDTH-1:0] wr_gray_rd1, wr_gray_rd2;
    logic                 full;
    logic                 empty;

    function automatic logic [PTR_WIDTH-1:0] bin_to_gray(input logic [PTR_WIDTH-1:0] bin);
        bin_to_gray = (bin >> 1) ^ bin;
    endfunction

    function automatic logic [PTR_WIDTH-1:0] gray_to_bin(input logic [PTR_WIDTH-1:0] gray);
        integer i;
        begin
            gray_to_bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
            for (i = PTR_WIDTH - 2; i >= 0; i = i - 1) begin
                gray_to_bin[i] = gray_to_bin[i + 1] ^ gray[i];
            end
        end
    endfunction

    assign wr_gray_plus_one = bin_to_gray(wr_bin + 1'b1);
    assign full = (wr_gray_plus_one == {~rd_gray_wr2[PTR_WIDTH-1:PTR_WIDTH-2], rd_gray_wr2[PTR_WIDTH-3:0]});
    assign empty = (rd_gray == wr_gray_rd2);

    assign wr_ready = !full;
    assign rd_valid = !empty;
    assign rd_data = mem[rd_bin[ADDR_WIDTH-1:0]];
    assign wr_full = full;
    assign rd_empty = empty;
    assign wr_level = wr_bin - gray_to_bin(rd_gray_wr2);
    assign rd_level = gray_to_bin(wr_gray_rd2) - rd_bin;

    always_ff @(posedge wr_clk or posedge wr_reset) begin
        if (wr_reset) begin
            wr_bin <= '0;
            wr_gray <= '0;
            rd_gray_wr1 <= '0;
            rd_gray_wr2 <= '0;
        end else begin
            rd_gray_wr1 <= rd_gray;
            rd_gray_wr2 <= rd_gray_wr1;

            if (wr_valid && wr_ready) begin
                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
                wr_bin <= wr_bin + 1'b1;
                wr_gray <= bin_to_gray(wr_bin + 1'b1);
            end
        end
    end

    always_ff @(posedge rd_clk or posedge rd_reset) begin
        if (rd_reset) begin
            rd_bin <= '0;
            rd_gray <= '0;
            wr_gray_rd1 <= '0;
            wr_gray_rd2 <= '0;
        end else begin
            wr_gray_rd1 <= wr_gray;
            wr_gray_rd2 <= wr_gray_rd1;

            if (rd_valid && rd_ready) begin
                rd_bin <= rd_bin + 1'b1;
                rd_gray <= bin_to_gray(rd_bin + 1'b1);
            end
        end
    end
endmodule

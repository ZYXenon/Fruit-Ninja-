`timescale 1ns/1ps

module tb_sram_arbiter;
    logic        clk = 1'b0;
    logic        reset = 1'b1;
    logic        wr_valid = 1'b0;
    logic        wr_ready;
    logic [19:0] wr_addr = 20'h10;
    logic [15:0] wr_data = 16'hCAFE;
    logic        rd_req = 1'b0;
    logic        rd_ready;
    logic [19:0] rd_addr = 20'h20;
    logic        rd_valid;
    logic [15:0] rd_data;
    logic [31:0] wr_accept_count;
    logic [31:0] rd_accept_count;
    logic [19:0] SRAM_ADDR;
    wire  [15:0] SRAM_DQ;
    logic        SRAM_CE_N;
    logic        SRAM_OE_N;
    logic        SRAM_WE_N;
    logic        SRAM_UB_N;
    logic        SRAM_LB_N;
    logic [31:0] wr_count_before;
    logic [31:0] rd_count_before;
    int          pulse_count;

    assign SRAM_DQ = (!SRAM_OE_N && SRAM_WE_N) ? 16'h1234 : 16'hzzzz;

    always #5 clk = ~clk;

    sram_arbiter dut (
        .clk             (clk),
        .reset           (reset),
        .wr_valid        (wr_valid),
        .wr_ready        (wr_ready),
        .wr_addr         (wr_addr),
        .wr_data         (wr_data),
        .rd_req          (rd_req),
        .rd_ready        (rd_ready),
        .rd_addr         (rd_addr),
        .rd_valid        (rd_valid),
        .rd_data         (rd_data),
        .wr_accept_count (wr_accept_count),
        .rd_accept_count (rd_accept_count),
        .SRAM_ADDR       (SRAM_ADDR),
        .SRAM_DQ         (SRAM_DQ),
        .SRAM_CE_N       (SRAM_CE_N),
        .SRAM_OE_N       (SRAM_OE_N),
        .SRAM_WE_N       (SRAM_WE_N),
        .SRAM_UB_N       (SRAM_UB_N),
        .SRAM_LB_N       (SRAM_LB_N)
    );

    initial begin
        repeat (3) @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        rd_req = 1'b1;
        wr_valid = 1'b0;
        rd_addr = 20'h20;

        @(posedge clk);
        assert(rd_ready) else $fatal(1, "single read request must be accepted from idle");
        #1;
        assert(!rd_valid) else $fatal(1, "read data must not be valid on accept cycle");

        @(posedge clk);
        #1;
        assert(rd_valid && (rd_data == 16'h1234))
            else $fatal(1, "read data must be valid one cycle after accept");

        @(negedge clk);
        wr_valid = 1'b1;
        rd_req = 1'b0;
        wr_count_before = wr_accept_count;
        rd_count_before = rd_accept_count;

        for (pulse_count = 0; pulse_count < 10; pulse_count = pulse_count + 1) begin
            @(negedge clk);
            rd_req = 1'b1;
            @(negedge clk);
            rd_req = 1'b0;
            repeat (2) @(negedge clk);
        end

        assert((wr_accept_count > wr_count_before) && (rd_accept_count > rd_count_before))
            else $fatal(1, "pulsed read requests must not starve writes");

        $finish;
    end
endmodule

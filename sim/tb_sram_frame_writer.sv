`timescale 1ns/1ps

module tb_sram_frame_writer;
    logic        clk = 1'b0;
    logic        reset = 1'b1;
    logic        fifo_valid = 1'b0;
    logic        fifo_ready;
    logic [17:0] fifo_data = 18'h0;
    logic        mem_wr_valid;
    logic        mem_wr_ready = 1'b1;
    logic [19:0] mem_wr_addr;
    logic [15:0] mem_wr_data;
    logic [1:0]  read_frame = 2'd2;
    logic        pending_consumed = 1'b0;
    logic [1:0]  pending_frame;
    logic        pending_valid;
    logic [31:0] accepted_pixel_count;
    logic [31:0] completed_frame_count;
    logic [31:0] dropped_frame_count;
    logic [16:0] debug_pixel_count;

    always #5 clk = ~clk;

    sram_frame_writer #(
        .FRAME_WORDS (4)
    ) dut (
        .clk                   (clk),
        .reset                 (reset),
        .fifo_valid            (fifo_valid),
        .fifo_ready            (fifo_ready),
        .fifo_data             (fifo_data),
        .mem_wr_valid          (mem_wr_valid),
        .mem_wr_ready          (mem_wr_ready),
        .mem_wr_addr           (mem_wr_addr),
        .mem_wr_data           (mem_wr_data),
        .read_frame            (read_frame),
        .pending_consumed      (pending_consumed),
        .pending_frame         (pending_frame),
        .pending_valid         (pending_valid),
        .accepted_pixel_count  (accepted_pixel_count),
        .completed_frame_count (completed_frame_count),
        .dropped_frame_count   (dropped_frame_count),
        .debug_pixel_count     (debug_pixel_count)
    );

    task automatic push_pixel(input logic sof, input logic [15:0] pixel);
        begin
            @(negedge clk);
            fifo_valid = 1'b1;
            fifo_data = {sof, 1'b0, pixel};
            wait (fifo_ready);
            @(negedge clk);
            fifo_valid = 1'b0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        reset = 1'b0;

        push_pixel(1'b1, 16'h0001);
        push_pixel(1'b0, 16'h0002);
        push_pixel(1'b0, 16'h0003);
        push_pixel(1'b0, 16'h0004);
        @(posedge clk);
        assert(pending_valid && completed_frame_count == 32'd1)
            else $fatal(1, "complete frame should be published");

        @(negedge clk);
        pending_consumed = 1'b1;
        @(negedge clk);
        pending_consumed = 1'b0;

        push_pixel(1'b1, 16'h0011);
        push_pixel(1'b0, 16'h0012);
        push_pixel(1'b1, 16'h0021);
        @(posedge clk);
        assert(dropped_frame_count == 32'd1 && !pending_valid)
            else $fatal(1, "new SOF before completion should drop previous partial frame");

        push_pixel(1'b0, 16'h0022);
        push_pixel(1'b0, 16'h0023);
        push_pixel(1'b0, 16'h0024);
        @(posedge clk);
        assert(pending_valid && completed_frame_count == 32'd2)
            else $fatal(1, "writer should recover and publish the next complete frame");

        $finish;
    end
endmodule

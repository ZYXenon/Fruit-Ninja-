`timescale 1ns/1ps

module tb_ov2640_capture;
    logic        pclk = 1'b0;
    logic        reset = 1'b1;
    logic [7:0]  cam_d = 8'h00;
    logic        cam_href = 1'b0;
    logic        cam_vsync = 1'b0;
    logic        fifo_wr_valid;
    logic        fifo_wr_ready = 1'b1;
    logic [17:0] fifo_wr_data;
    logic        overflow;
    logic        overflow_pulse;
    logic        drop_frame;
    logic [31:0] overflow_count;
    logic [31:0] accepted_pixel_count;

    always #5 pclk = ~pclk;

    ov2640_capture dut (
        .pclk                 (pclk),
        .reset                (reset),
        .cam_d                (cam_d),
        .cam_href             (cam_href),
        .cam_vsync            (cam_vsync),
        .fifo_wr_valid        (fifo_wr_valid),
        .fifo_wr_ready        (fifo_wr_ready),
        .fifo_wr_data         (fifo_wr_data),
        .overflow             (overflow),
        .overflow_pulse       (overflow_pulse),
        .drop_frame           (drop_frame),
        .overflow_count       (overflow_count),
        .accepted_pixel_count (accepted_pixel_count)
    );

    task automatic send_pixel(input logic [7:0] hi, input logic [7:0] lo);
        begin
            @(negedge pclk);
            cam_href = 1'b1;
            cam_d = hi;
            @(negedge pclk);
            cam_d = lo;
            @(posedge pclk);
            #1;
            cam_href = 1'b0;
        end
    endtask

    initial begin
        repeat (3) @(negedge pclk);
        reset = 1'b0;
        cam_vsync = 1'b1;

        send_pixel(8'h12, 8'h34);
        assert(!fifo_wr_valid)
            else $fatal(1, "pixels before a real VSYNC gap must be ignored");

        @(negedge pclk);
        cam_vsync = 1'b0;
        repeat (2) @(negedge pclk);
        cam_vsync = 1'b1;

        send_pixel(8'h12, 8'h34);
        assert(fifo_wr_valid && fifo_wr_data == {1'b1, 1'b0, 16'h3412})
            else $fatal(1, "first pixel after VSYNC gap should be accepted with SOF");

        @(negedge pclk);
        cam_href = 1'b1;
        cam_d = 8'h56;
        @(negedge pclk);
        fifo_wr_ready = 1'b0;
        cam_d = 8'h78;
        @(posedge pclk);
        #1;
        assert(overflow_pulse && drop_frame && !fifo_wr_valid)
            else $fatal(1, "FIFO full should pulse overflow and enter frame drop");

        @(negedge pclk);
        fifo_wr_ready = 1'b1;
        cam_href = 1'b0;
        send_pixel(8'h9A, 8'hBC);
        assert(!fifo_wr_valid)
            else $fatal(1, "pixels after overflow must be suppressed until next frame");

        @(negedge pclk);
        cam_vsync = 1'b0;
        repeat (2) @(negedge pclk);
        cam_vsync = 1'b1;
        send_pixel(8'hDE, 8'hF0);
        assert(fifo_wr_valid && fifo_wr_data == {1'b1, 1'b0, 16'hF0DE})
            else $fatal(1, "next frame should resume at SOF");

        $finish;
    end
endmodule

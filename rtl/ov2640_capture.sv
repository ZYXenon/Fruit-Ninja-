module ov2640_capture (
    input  logic        pclk,
    input  logic        reset,
    input  logic [7:0]  cam_d,
    input  logic        cam_href,
    input  logic        cam_vsync,

    output logic        fifo_wr_valid,
    input  logic        fifo_wr_ready,
    output logic [17:0] fifo_wr_data,
    output logic        overflow,
    output logic        overflow_pulse,
    output logic        drop_frame,
    output logic [31:0] overflow_count,
    output logic [31:0] accepted_pixel_count
);

    logic [7:0] first_byte;
    logic       have_first_byte;
    logic       seen_frame_gap;
    logic       frame_active;

    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            first_byte <= 8'h00;
            have_first_byte <= 1'b0;
            seen_frame_gap <= 1'b0;
            frame_active <= 1'b0;
            fifo_wr_valid <= 1'b0;
            fifo_wr_data <= 18'h0;
            overflow <= 1'b0;
            overflow_pulse <= 1'b0;
            drop_frame <= 1'b0;
            overflow_count <= 32'd0;
            accepted_pixel_count <= 32'd0;
        end else begin
            fifo_wr_valid <= 1'b0;
            overflow_pulse <= 1'b0;

            if (!cam_vsync) begin
                have_first_byte <= 1'b0;
                seen_frame_gap <= 1'b1;
                frame_active <= 1'b0;
                drop_frame <= 1'b0;
            end else if (drop_frame) begin
                have_first_byte <= 1'b0;
            end else if (cam_href) begin
                if (!have_first_byte) begin
                    first_byte <= cam_d;
                    have_first_byte <= 1'b1;
                end else begin
                    have_first_byte <= 1'b0;
                    if (!seen_frame_gap && !frame_active) begin
                        // Wait for a real VSYNC gap after reset before accepting a frame.
                    end else if (fifo_wr_ready) begin
                        fifo_wr_valid <= 1'b1;
                        fifo_wr_data <= {seen_frame_gap, 1'b0, cam_d, first_byte};
                        seen_frame_gap <= 1'b0;
                        frame_active <= 1'b1;
                        accepted_pixel_count <= accepted_pixel_count + 1'b1;
                    end else begin
                        overflow <= 1'b1;
                        overflow_pulse <= 1'b1;
                        overflow_count <= overflow_count + 1'b1;
                        drop_frame <= 1'b1;
                    end
                end
            end else begin
                have_first_byte <= 1'b0;
            end
        end
    end
endmodule

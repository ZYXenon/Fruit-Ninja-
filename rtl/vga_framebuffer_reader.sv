module vga_framebuffer_reader (
    input  logic        clk,
    input  logic        reset,
    input  logic [9:0]  draw_x,
    input  logic [9:0]  draw_y,
    input  logic        blank_n,

    input  logic [1:0]  pending_frame,
    input  logic        pending_valid,
    output logic        pending_consumed,
    output logic [1:0]  read_frame,

    output logic        mem_rd_req,
    input  logic        mem_rd_ready,
    output logic [19:0] mem_rd_addr,
    input  logic        mem_rd_valid,
    input  logic [15:0] mem_rd_data,

    output logic [15:0] pixel,
    output logic        pixel_valid
);

    (* ramstyle = "M10K" *) logic [15:0] line_buf0 [0:319];
    (* ramstyle = "M10K" *) logic [15:0] line_buf1 [0:319];

    logic [8:0]  buf_y0, buf_y1;
    logic        buf_valid0, buf_valid1;
    logic        current_buf;
    logic        current_valid;
    logic        fill_active;
    logic        fill_buf;
    logic [8:0]  fill_y;
    logic [8:0]  fill_x;
    logic [8:0]  rd_x_hold;
    logic [8:0]  rd_y_hold;
    logic        rd_buf_hold;
    logic        line_done_pending;
    logic [19:0] fill_addr;
    logic [9:0]  draw_x_d;
    logic [8:0]  source_x;
    logic        pixel_buf_sel;
    logic        pixel_line_valid;
    logic        new_line;
    logic        new_frame;
    logic        rd_accepted;

    function automatic logic [19:0] frame_base(input logic [1:0] frame);
        case (frame)
            2'd0: frame_base = 20'd0;
            2'd1: frame_base = 20'd76800;
            default: frame_base = 20'd153600;
        endcase
    endfunction

    function automatic logic [19:0] line_offset(input logic [8:0] y);
        logic [19:0] y_ext;
        begin
            y_ext = {11'd0, y};
            line_offset = (y_ext << 8) + (y_ext << 6);
        end
    endfunction

    function automatic logic buffer_has_y(input logic [8:0] y);
        buffer_has_y = (buf_valid0 && (buf_y0 == y)) || (buf_valid1 && (buf_y1 == y));
    endfunction

    assign new_line = (draw_x == 10'd0) && (draw_x_d != 10'd0);
    assign new_frame = new_line && (draw_y == 10'd0);
    assign source_x = (draw_x < 10'd640) ? draw_x[9:1] : 9'd0;
    assign rd_accepted = mem_rd_req && mem_rd_ready;

    always_comb begin
        pixel_buf_sel = current_buf;
        pixel_line_valid = current_valid;

        if (new_frame && pending_valid) begin
            pixel_line_valid = 1'b0;
        end else if (new_line) begin
            if (buf_valid0 && (buf_y0 == draw_y[9:1])) begin
                pixel_buf_sel = 1'b0;
                pixel_line_valid = 1'b1;
            end else if (buf_valid1 && (buf_y1 == draw_y[9:1])) begin
                pixel_buf_sel = 1'b1;
                pixel_line_valid = 1'b1;
            end else begin
                pixel_line_valid = 1'b0;
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            draw_x_d <= 10'd0;
            read_frame <= 2'd0;
            pending_consumed <= 1'b0;
            buf_y0 <= 9'd0;
            buf_y1 <= 9'd0;
            buf_valid0 <= 1'b0;
            buf_valid1 <= 1'b0;
            current_buf <= 1'b0;
            current_valid <= 1'b0;
            fill_active <= 1'b0;
            fill_buf <= 1'b0;
            fill_y <= 9'd0;
            fill_x <= 9'd0;
            rd_x_hold <= 9'd0;
            rd_y_hold <= 9'd0;
            rd_buf_hold <= 1'b0;
            line_done_pending <= 1'b0;
            fill_addr <= 20'd0;
            mem_rd_req <= 1'b0;
            mem_rd_addr <= 20'd0;
            pixel <= 16'h0000;
            pixel_valid <= 1'b0;
        end else begin
            draw_x_d <= draw_x;
            pending_consumed <= 1'b0;

            if (pixel_buf_sel == 1'b0) begin
                pixel <= line_buf0[source_x];
            end else begin
                pixel <= line_buf1[source_x];
            end
            pixel_valid <= blank_n && pixel_line_valid && (draw_x < 10'd640) && (draw_y < 10'd480);

            if (new_frame && pending_valid) begin
                read_frame <= pending_frame;
                pending_consumed <= 1'b1;
                buf_valid0 <= 1'b0;
                buf_valid1 <= 1'b0;
                fill_active <= 1'b0;
                line_done_pending <= 1'b0;
                mem_rd_req <= 1'b0;
            end

            if (new_line || (new_frame && pending_valid)) begin
                current_buf <= pixel_buf_sel;
                current_valid <= pixel_line_valid;
            end

            if (!new_line && !fill_active && !mem_rd_req && (draw_y < 10'd480)) begin
                if (!buffer_has_y(draw_y[9:1])) begin
                    fill_active <= 1'b1;
                    fill_buf <= ~current_buf;
                    fill_y <= draw_y[9:1];
                    fill_x <= 9'd0;
                    fill_addr <= frame_base(read_frame) + line_offset(draw_y[9:1]);
                    line_done_pending <= 1'b0;
                end else if ((draw_y[9:1] < 9'd239) && !buffer_has_y(draw_y[9:1] + 1'b1)) begin
                    fill_active <= 1'b1;
                    fill_buf <= ~current_buf;
                    fill_y <= draw_y[9:1] + 1'b1;
                    fill_x <= 9'd0;
                    fill_addr <= frame_base(read_frame) + line_offset(draw_y[9:1] + 1'b1);
                    line_done_pending <= 1'b0;
                end
            end

            if (rd_accepted) begin
                mem_rd_req <= 1'b0;
                rd_x_hold <= fill_x;
                rd_y_hold <= fill_y;
                rd_buf_hold <= fill_buf;

                if (fill_x == 9'd319) begin
                    line_done_pending <= 1'b1;
                end else begin
                    fill_x <= fill_x + 1'b1;
                    fill_addr <= fill_addr + 20'd1;
                end
            end else if (fill_active && !line_done_pending && !mem_rd_req) begin
                mem_rd_req <= 1'b1;
                mem_rd_addr <= fill_addr;
            end

            if (mem_rd_valid) begin
                if (rd_buf_hold == 1'b0) begin
                    line_buf0[rd_x_hold] <= mem_rd_data;
                    buf_y0 <= rd_y_hold;
                    if (rd_x_hold == 9'd319) begin
                        buf_valid0 <= 1'b1;
                        fill_active <= 1'b0;
                        line_done_pending <= 1'b0;
                    end
                end else begin
                    line_buf1[rd_x_hold] <= mem_rd_data;
                    buf_y1 <= rd_y_hold;
                    if (rd_x_hold == 9'd319) begin
                        buf_valid1 <= 1'b1;
                        fill_active <= 1'b0;
                        line_done_pending <= 1'b0;
                    end
                end
            end
        end
    end
endmodule

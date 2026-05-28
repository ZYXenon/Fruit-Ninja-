module knife_trail_renderer (
    input  logic       clk,
    input  logic       reset,
    input  logic       frame_tick,
    input  logic       knife_valid,
    input  logic [9:0] knife_x,
    input  logic [9:0] knife_y,
    input  logic [9:0] draw_x,
    input  logic [9:0] draw_y,
    input  logic [7:0] bg_r,
    input  logic [7:0] bg_g,
    input  logic [7:0] bg_b,

    output logic [7:0] out_r,
    output logic [7:0] out_g,
    output logic [7:0] out_b
);

    localparam int TRAIL_LEN = 8;

    logic [9:0] trail_x [0:TRAIL_LEN-1];
    logic [9:0] trail_y [0:TRAIL_LEN-1];
    logic       trail_valid [0:TRAIL_LEN-1];

    localparam logic signed [11:0] HEAD_LINE_HALF_WIDTH = 12'sd7;
    localparam logic signed [11:0] TAIL_LINE_HALF_WIDTH = 12'sd1;
    localparam logic signed [11:0] HEAD_CAP_RADIUS = 12'sd8;
    localparam logic signed [11:0] TAIL_CAP_RADIUS = 12'sd1;

    logic signed [11:0] draw_x_s;
    logic signed [11:0] draw_y_s;
    logic signed [11:0] dx;
    logic signed [11:0] dy;
    logic signed [11:0] seg_dx;
    logic signed [11:0] seg_dy;
    logic signed [11:0] pix_dx;
    logic signed [11:0] pix_dy;
    logic signed [11:0] min_x;
    logic signed [11:0] max_x;
    logic signed [11:0] min_y;
    logic signed [11:0] max_y;
    logic signed [25:0] cross_term;
    logic [25:0] cross_abs;
    logic [25:0] cross_limit;
    logic [11:0] abs_dx;
    logic [11:0] abs_dy;
    logic [11:0] abs_seg_dx;
    logic [11:0] abs_seg_dy;
    logic [12:0] seg_manhattan;
    logic signed [11:0] point_cap_radius;
    logic signed [11:0] segment_half_width;
    logic signed [11:0] segment_bound_radius;
    logic       trail_hit;

    function automatic logic [11:0] abs12(input logic signed [11:0] value);
        abs12 = value[11] ? $unsigned(-value) : $unsigned(value);
    endfunction

    function automatic logic [25:0] abs26(input logic signed [25:0] value);
        abs26 = value[25] ? $unsigned(-value) : $unsigned(value);
    endfunction

    function automatic logic signed [11:0] point_radius(input int index);
        case (index)
            0: point_radius = HEAD_CAP_RADIUS;
            1: point_radius = 12'sd7;
            2: point_radius = 12'sd6;
            3: point_radius = 12'sd5;
            4: point_radius = 12'sd4;
            5: point_radius = 12'sd3;
            6: point_radius = 12'sd2;
            default: point_radius = TAIL_CAP_RADIUS;
        endcase
    endfunction

    function automatic logic signed [11:0] segment_width(input int index);
        case (index)
            0: segment_width = HEAD_LINE_HALF_WIDTH;
            1: segment_width = 12'sd6;
            2: segment_width = 12'sd5;
            3: segment_width = 12'sd4;
            4: segment_width = 12'sd3;
            5: segment_width = 12'sd2;
            6: segment_width = TAIL_LINE_HALF_WIDTH;
            default: segment_width = TAIL_LINE_HALF_WIDTH;
        endcase
    endfunction

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < TRAIL_LEN; i = i + 1) begin
                trail_x[i] <= 10'd0;
                trail_y[i] <= 10'd0;
                trail_valid[i] <= 1'b0;
            end
        end else if (frame_tick) begin
            if (knife_valid) begin
                for (int i = TRAIL_LEN - 1; i > 0; i = i - 1) begin
                    trail_x[i] <= trail_x[i - 1];
                    trail_y[i] <= trail_y[i - 1];
                    trail_valid[i] <= trail_valid[i - 1];
                end

                trail_x[0] <= knife_x;
                trail_y[0] <= knife_y;
                trail_valid[0] <= 1'b1;
            end else begin
                for (int i = 0; i < TRAIL_LEN; i = i + 1) begin
                    trail_x[i] <= 10'd0;
                    trail_y[i] <= 10'd0;
                    trail_valid[i] <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        draw_x_s = $signed({2'b00, draw_x});
        draw_y_s = $signed({2'b00, draw_y});
        dx = 12'sd0;
        dy = 12'sd0;
        seg_dx = 12'sd0;
        seg_dy = 12'sd0;
        pix_dx = 12'sd0;
        pix_dy = 12'sd0;
        min_x = 12'sd0;
        max_x = 12'sd0;
        min_y = 12'sd0;
        max_y = 12'sd0;
        cross_term = 26'sd0;
        cross_abs = 26'd0;
        cross_limit = 26'd0;
        abs_dx = 12'd0;
        abs_dy = 12'd0;
        abs_seg_dx = 12'd0;
        abs_seg_dy = 12'd0;
        seg_manhattan = 13'd0;
        point_cap_radius = TAIL_CAP_RADIUS;
        segment_half_width = TAIL_LINE_HALF_WIDTH;
        segment_bound_radius = TAIL_CAP_RADIUS;
        trail_hit = 1'b0;

        out_r = bg_r;
        out_g = bg_g;
        out_b = bg_b;

        for (int i = TRAIL_LEN - 1; i >= 0; i = i - 1) begin
            dx = draw_x_s - $signed({2'b00, trail_x[i]});
            dy = draw_y_s - $signed({2'b00, trail_y[i]});
            abs_dx = abs12(dx);
            abs_dy = abs12(dy);
            point_cap_radius = point_radius(i);

            if (trail_valid[i] &&
                ((abs_dx + abs_dy) <= $unsigned(point_cap_radius))) begin
                trail_hit = 1'b1;
            end
        end

        for (int i = TRAIL_LEN - 2; i >= 0; i = i - 1) begin
            if (trail_valid[i] && trail_valid[i + 1]) begin
                segment_half_width = segment_width(i);
                segment_bound_radius = point_radius(i);
                seg_dx = $signed({2'b00, trail_x[i]}) - $signed({2'b00, trail_x[i + 1]});
                seg_dy = $signed({2'b00, trail_y[i]}) - $signed({2'b00, trail_y[i + 1]});
                pix_dx = draw_x_s - $signed({2'b00, trail_x[i + 1]});
                pix_dy = draw_y_s - $signed({2'b00, trail_y[i + 1]});
                abs_seg_dx = abs12(seg_dx);
                abs_seg_dy = abs12(seg_dy);
                seg_manhattan = {1'b0, abs_seg_dx} + {1'b0, abs_seg_dy};
                cross_term = (pix_dx * seg_dy) - (pix_dy * seg_dx);
                cross_abs = abs26(cross_term);
                cross_limit = segment_half_width * {13'd0, seg_manhattan};

                if (trail_x[i] < trail_x[i + 1]) begin
                    min_x = $signed({2'b00, trail_x[i]});
                    max_x = $signed({2'b00, trail_x[i + 1]});
                end else begin
                    min_x = $signed({2'b00, trail_x[i + 1]});
                    max_x = $signed({2'b00, trail_x[i]});
                end

                if (trail_y[i] < trail_y[i + 1]) begin
                    min_y = $signed({2'b00, trail_y[i]});
                    max_y = $signed({2'b00, trail_y[i + 1]});
                end else begin
                    min_y = $signed({2'b00, trail_y[i + 1]});
                    max_y = $signed({2'b00, trail_y[i]});
                end

                if ((seg_manhattan != 13'd0) &&
                    (draw_x_s >= (min_x - segment_bound_radius)) &&
                    (draw_x_s <= (max_x + segment_bound_radius)) &&
                    (draw_y_s >= (min_y - segment_bound_radius)) &&
                    (draw_y_s <= (max_y + segment_bound_radius)) &&
                    (cross_abs <= cross_limit)) begin
                    trail_hit = 1'b1;
                end
            end
        end

        if (trail_hit) begin
            out_r = 8'hff;
            out_g = 8'hff;
            out_b = 8'hff;
        end
    end

endmodule

module color_prop_tracker (
    input  logic        clk,
    input  logic        reset,

    input  logic        frame_start,
    input  logic        frame_end,
    input  logic        pix_valid,
    input  logic [9:0]  pix_x,
    input  logic [9:0]  pix_y,
    input  logic [15:0] pix_rgb565,

    input  logic [4:0]  r_min,
    input  logic [4:0]  r_max,
    input  logic [5:0]  g_min,
    input  logic [5:0]  g_max,
    input  logic [4:0]  b_min,
    input  logic [4:0]  b_max,
    input  logic [5:0]  dominance_margin,
    input  logic [5:0]  blue_margin,
    input  logic [15:0] count_min,

    output logic        prop_valid,
    output logic [9:0]  prop_x,
    output logic [9:0]  prop_y,
    output logic [9:0]  bbox_min_x,
    output logic [9:0]  bbox_min_y,
    output logic [9:0]  bbox_max_x,
    output logic [9:0]  bbox_max_y,
    output logic [15:0] prop_count
);

    localparam logic [9:0] MAX_BBOX_W = 10'd220;
    localparam logic [9:0] MAX_BBOX_H = 10'd220;
    localparam logic [9:0] CORNER_GUARD_X = 10'd144;
    localparam logic [9:0] CORNER_GUARD_Y = 10'd144;
    localparam logic [9:0] CORNER_MIN_BBOX_W = 10'd12;
    localparam logic [9:0] CORNER_MIN_BBOX_H = 10'd12;
    localparam logic [15:0] CORNER_STRONG_COUNT = 16'd32;
    localparam logic [3:0] MISS_HOLD_FRAMES = 4'd0;

    logic [4:0] r5;
    logic [5:0] g6;
    logic [4:0] b5;
    logic [5:0] r6;
    logic [5:0] b6;
    logic [6:0] r7;
    logic [6:0] g7;
    logic [6:0] b7;
    logic [6:0] margin7;
    logic [6:0] blue_margin7;
    logic [7:0] green2;
    logic [7:0] rb_sum;
    logic [7:0] saturation_margin8;
    logic       green_hit;
    logic       is_prop;
    logic       active_pixel;

    logic [1:0] pix_zone;
    logic [1:0] selected_zone;
    logic [9:0] zone_min_x [0:3];
    logic [9:0] zone_min_y [0:3];
    logic [9:0] zone_max_x [0:3];
    logic [9:0] zone_max_y [0:3];
    logic [15:0] zone_count [0:3];
    logic [9:0] zone_bbox_w [0:3];
    logic [9:0] zone_bbox_h [0:3];
    logic       zone_corner_noise [0:3];
    logic       zone_candidate_ok [0:3];
    logic       selected_valid;
    logic [15:0] selected_count;
    logic [9:0] selected_min_x;
    logic [9:0] selected_min_y;
    logic [9:0] selected_max_x;
    logic [9:0] selected_max_y;
    logic [10:0] selected_center_x_sum;
    logic [10:0] selected_center_y_sum;
    logic [3:0] miss_hold_count;
    integer     zone_reset_index;

    assign r5 = pix_rgb565[15:11];
    assign g6 = pix_rgb565[10:5];
    assign b5 = pix_rgb565[4:0];
    assign r6 = {r5, 1'b0};
    assign b6 = {b5, 1'b0};
    assign r7 = {1'b0, r6};
    assign g7 = {1'b0, g6};
    assign b7 = {1'b0, b6};
    assign margin7 = {1'b0, dominance_margin};
    assign blue_margin7 = {1'b0, blue_margin};
    assign green2 = {g7, 1'b0};
    assign rb_sum = {1'b0, r7} + {1'b0, b7};
    assign saturation_margin8 = {1'b0, margin7};

    assign active_pixel = pix_valid && (pix_x < 10'd640) && (pix_y < 10'd480);
    assign green_hit = (g7 > (r7 + margin7)) &&
                       ((g7 + blue_margin7) > b7) &&
                       (green2 > (rb_sum + saturation_margin8));
    assign is_prop = (r5 >= r_min) &&
                     (r5 <= r_max) &&
                     (g6 >= g_min) &&
                     (g6 <= g_max) &&
                     (b5 >= b_min) &&
                     (b5 <= b_max) &&
                     green_hit;

    always_comb begin
        if (pix_x < 10'd160) begin
            pix_zone = 2'd0;
        end else if (pix_x < 10'd320) begin
            pix_zone = 2'd1;
        end else if (pix_x < 10'd480) begin
            pix_zone = 2'd2;
        end else begin
            pix_zone = 2'd3;
        end

        selected_zone = 2'd0;
        selected_count = 16'd0;
        selected_valid = 1'b0;

        if (zone_candidate_ok[0] && (!selected_valid || (zone_count[0] > selected_count))) begin
            selected_zone = 2'd0;
            selected_count = zone_count[0];
            selected_valid = 1'b1;
        end

        if (zone_candidate_ok[1] && (!selected_valid || (zone_count[1] > selected_count))) begin
            selected_zone = 2'd1;
            selected_count = zone_count[1];
            selected_valid = 1'b1;
        end

        if (zone_candidate_ok[2] && (!selected_valid || (zone_count[2] > selected_count))) begin
            selected_zone = 2'd2;
            selected_count = zone_count[2];
            selected_valid = 1'b1;
        end

        if (zone_candidate_ok[3] && (!selected_valid || (zone_count[3] > selected_count))) begin
            selected_zone = 2'd3;
            selected_count = zone_count[3];
            selected_valid = 1'b1;
        end
    end

    assign zone_bbox_w[0] = zone_max_x[0] - zone_min_x[0];
    assign zone_bbox_h[0] = zone_max_y[0] - zone_min_y[0];
    assign zone_bbox_w[1] = zone_max_x[1] - zone_min_x[1];
    assign zone_bbox_h[1] = zone_max_y[1] - zone_min_y[1];
    assign zone_bbox_w[2] = zone_max_x[2] - zone_min_x[2];
    assign zone_bbox_h[2] = zone_max_y[2] - zone_min_y[2];
    assign zone_bbox_w[3] = zone_max_x[3] - zone_min_x[3];
    assign zone_bbox_h[3] = zone_max_y[3] - zone_min_y[3];
    assign zone_corner_noise[0] = (zone_min_x[0] < CORNER_GUARD_X) &&
                                  (zone_min_y[0] < CORNER_GUARD_Y) &&
                                  (zone_count[0] < CORNER_STRONG_COUNT) &&
                                  ((zone_bbox_w[0] < CORNER_MIN_BBOX_W) ||
                                   (zone_bbox_h[0] < CORNER_MIN_BBOX_H));
    assign zone_corner_noise[1] = (zone_min_x[1] < CORNER_GUARD_X) &&
                                  (zone_min_y[1] < CORNER_GUARD_Y) &&
                                  (zone_count[1] < CORNER_STRONG_COUNT) &&
                                  ((zone_bbox_w[1] < CORNER_MIN_BBOX_W) ||
                                   (zone_bbox_h[1] < CORNER_MIN_BBOX_H));
    assign zone_corner_noise[2] = (zone_min_x[2] < CORNER_GUARD_X) &&
                                  (zone_min_y[2] < CORNER_GUARD_Y) &&
                                  (zone_count[2] < CORNER_STRONG_COUNT) &&
                                  ((zone_bbox_w[2] < CORNER_MIN_BBOX_W) ||
                                   (zone_bbox_h[2] < CORNER_MIN_BBOX_H));
    assign zone_corner_noise[3] = (zone_min_x[3] < CORNER_GUARD_X) &&
                                  (zone_min_y[3] < CORNER_GUARD_Y) &&
                                  (zone_count[3] < CORNER_STRONG_COUNT) &&
                                  ((zone_bbox_w[3] < CORNER_MIN_BBOX_W) ||
                                   (zone_bbox_h[3] < CORNER_MIN_BBOX_H));
    assign zone_candidate_ok[0] = (zone_count[0] >= count_min) &&
                                  (zone_bbox_w[0] <= MAX_BBOX_W) &&
                                  (zone_bbox_h[0] <= MAX_BBOX_H) &&
                                  !zone_corner_noise[0];
    assign zone_candidate_ok[1] = (zone_count[1] >= count_min) &&
                                  (zone_bbox_w[1] <= MAX_BBOX_W) &&
                                  (zone_bbox_h[1] <= MAX_BBOX_H) &&
                                  !zone_corner_noise[1];
    assign zone_candidate_ok[2] = (zone_count[2] >= count_min) &&
                                  (zone_bbox_w[2] <= MAX_BBOX_W) &&
                                  (zone_bbox_h[2] <= MAX_BBOX_H) &&
                                  !zone_corner_noise[2];
    assign zone_candidate_ok[3] = (zone_count[3] >= count_min) &&
                                  (zone_bbox_w[3] <= MAX_BBOX_W) &&
                                  (zone_bbox_h[3] <= MAX_BBOX_H) &&
                                  !zone_corner_noise[3];
    assign selected_min_x = zone_min_x[selected_zone];
    assign selected_min_y = zone_min_y[selected_zone];
    assign selected_max_x = zone_max_x[selected_zone];
    assign selected_max_y = zone_max_y[selected_zone];
    assign selected_center_x_sum = {1'b0, selected_min_x} + {1'b0, selected_max_x};
    assign selected_center_y_sum = {1'b0, selected_min_y} + {1'b0, selected_max_y};

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            prop_valid <= 1'b0;
            prop_x <= 10'd0;
            prop_y <= 10'd0;
            bbox_min_x <= 10'd0;
            bbox_min_y <= 10'd0;
            bbox_max_x <= 10'd0;
            bbox_max_y <= 10'd0;
            prop_count <= 16'd0;
            for (zone_reset_index = 0; zone_reset_index < 4; zone_reset_index = zone_reset_index + 1) begin
                zone_min_x[zone_reset_index] <= 10'd639;
                zone_min_y[zone_reset_index] <= 10'd479;
                zone_max_x[zone_reset_index] <= 10'd0;
                zone_max_y[zone_reset_index] <= 10'd0;
                zone_count[zone_reset_index] <= 16'd0;
            end
            miss_hold_count <= 4'd0;
        end else if (frame_start) begin
            prop_count <= 16'd0;
            for (zone_reset_index = 0; zone_reset_index < 4; zone_reset_index = zone_reset_index + 1) begin
                zone_min_x[zone_reset_index] <= 10'd639;
                zone_min_y[zone_reset_index] <= 10'd479;
                zone_max_x[zone_reset_index] <= 10'd0;
                zone_max_y[zone_reset_index] <= 10'd0;
                zone_count[zone_reset_index] <= 16'd0;
            end
        end else begin
            if (active_pixel && is_prop) begin
                if (prop_count != 16'hffff) begin
                    prop_count <= prop_count + 16'd1;
                end

                if (zone_count[pix_zone] != 16'hffff) begin
                    zone_count[pix_zone] <= zone_count[pix_zone] + 16'd1;
                end

                if (pix_x < zone_min_x[pix_zone]) begin
                    zone_min_x[pix_zone] <= pix_x;
                end

                if (pix_y < zone_min_y[pix_zone]) begin
                    zone_min_y[pix_zone] <= pix_y;
                end

                if (pix_x > zone_max_x[pix_zone]) begin
                    zone_max_x[pix_zone] <= pix_x;
                end

                if (pix_y > zone_max_y[pix_zone]) begin
                    zone_max_y[pix_zone] <= pix_y;
                end
            end

            if (frame_end) begin
                if (selected_valid) begin
                    prop_valid <= 1'b1;
                    prop_x <= selected_center_x_sum[10:1];
                    prop_y <= selected_center_y_sum[10:1];
                    bbox_min_x <= selected_min_x;
                    bbox_min_y <= selected_min_y;
                    bbox_max_x <= selected_max_x;
                    bbox_max_y <= selected_max_y;
                    miss_hold_count <= 4'd0;
                end else if (prop_valid && (miss_hold_count < MISS_HOLD_FRAMES)) begin
                    prop_valid <= 1'b1;
                    miss_hold_count <= miss_hold_count + 4'd1;
                end else begin
                    prop_valid <= 1'b0;
                    miss_hold_count <= 4'd0;
                end
            end
        end
    end

endmodule

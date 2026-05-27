module slice_effect_renderer (
    input  logic               clk,
    input  logic               reset,
    input  logic               effect_active,
    input  logic [2:0]         effect_type,
    input  logic signed [11:0] effect_x,
    input  logic signed [11:0] effect_y,
    input  logic [4:0]         effect_age,
    input  logic [9:0]         DrawX,
    input  logic [9:0]         DrawY,

    output logic               effect_hit,
    output logic [9:0]         effect_r,
    output logic [9:0]         effect_g,
    output logic [9:0]         effect_b
);

    localparam logic [2:0] FRUIT_BOMB = 3'd5;

    logic signed [11:0] draw_x_s;
    logic signed [11:0] draw_y_s;
    logic signed [11:0] dx;
    logic signed [11:0] dy;
    logic [11:0] abs_dx;
    logic [11:0] abs_dy;
    logic [11:0] radius;
    logic ring_hit;
    logic slash_hit;
    logic spark_hit;
    logic signed [11:0] left_dx;
    logic signed [11:0] left_dy;
    logic signed [11:0] right_dx;
    logic signed [11:0] right_dy;
    logic [11:0] left_abs_dx;
    logic [11:0] left_abs_dy;
    logic [11:0] right_abs_dx;
    logic [11:0] right_abs_dy;
    logic signed [11:0] left_center_x;
    logic signed [11:0] right_center_x;
    logic signed [11:0] half_center_y;
    logic signed [11:0] left_sprite_left;
    logic signed [11:0] left_sprite_top;
    logic signed [11:0] right_sprite_left;
    logic signed [11:0] right_sprite_top;
    logic [11:0] age_ext;
    logic [23:0] age_square;
    logic [11:0] split_offset;
    logic [11:0] fall_offset;
    logic left_inside;
    logic right_inside;
    logic signed [11:0] left_sprite_x_offset;
    logic signed [11:0] left_sprite_y_offset;
    logic signed [11:0] right_sprite_x_offset;
    logic signed [11:0] right_sprite_y_offset;
    logic [6:0] left_sprite_x;
    logic [6:0] left_sprite_y;
    logic [6:0] right_sprite_x;
    logic [6:0] right_sprite_y;
    logic [6:0] left_sprite_w;
    logic [6:0] left_sprite_h;
    logic [6:0] right_sprite_w;
    logic [6:0] right_sprite_h;
    logic [6:0] left_texture_w;
    logic [6:0] left_texture_h;
    logic [6:0] right_texture_w;
    logic [6:0] right_texture_h;
    logic [8:0] left_pixel;
    logic [8:0] right_pixel;
    logic fruit_halves_hit;
    logic bomb_effect_hit;
    logic left_inside_q;
    logic right_inside_q;

    function automatic logic [6:0] div3(input logic [6:0] value);
        div3 = value / 7'd3;
    endfunction

    assign draw_x_s = $signed({2'b00, DrawX});
    assign draw_y_s = $signed({2'b00, DrawY});
    assign dx = draw_x_s - effect_x;
    assign dy = draw_y_s - effect_y;
    assign radius = 12'd10 + {7'd0, effect_age};
    assign age_ext = {7'd0, effect_age};
    assign age_square = age_ext * age_ext;
    assign split_offset = age_ext << 1;
    assign fall_offset = age_square[13:2];
    assign left_center_x = effect_x - $signed(split_offset);
    assign right_center_x = effect_x + $signed(split_offset);
    assign half_center_y = effect_y - $signed(age_ext << 1) + $signed(fall_offset);
    assign left_sprite_left = left_center_x - $signed({5'd0, left_sprite_w[6:1]});
    assign left_sprite_top = half_center_y - $signed({5'd0, left_sprite_h[6:1]});
    assign right_sprite_left = right_center_x - $signed({5'd0, right_sprite_w[6:1]});
    assign right_sprite_top = half_center_y - $signed({5'd0, right_sprite_h[6:1]});
    assign left_dx = draw_x_s - left_center_x;
    assign left_dy = draw_y_s - half_center_y;
    assign right_dx = draw_x_s - right_center_x;
    assign right_dy = draw_y_s - half_center_y;
    assign left_sprite_x_offset = draw_x_s - left_sprite_left;
    assign left_sprite_y_offset = draw_y_s - left_sprite_top;
    assign right_sprite_x_offset = draw_x_s - right_sprite_left;
    assign right_sprite_y_offset = draw_y_s - right_sprite_top;

    always_comb begin
        abs_dx = dx[11] ? $unsigned(-dx) : $unsigned(dx);
        abs_dy = dy[11] ? $unsigned(-dy) : $unsigned(dy);
        left_abs_dx = left_dx[11] ? $unsigned(-left_dx) : $unsigned(left_dx);
        left_abs_dy = left_dy[11] ? $unsigned(-left_dy) : $unsigned(left_dy);
        right_abs_dx = right_dx[11] ? $unsigned(-right_dx) : $unsigned(right_dx);
        right_abs_dy = right_dy[11] ? $unsigned(-right_dy) : $unsigned(right_dy);
    end

    assign ring_hit = ((abs_dx + abs_dy) >= radius) &&
                      ((abs_dx + abs_dy) < (radius + 12'd4)) &&
                      (abs_dx < 12'd48) &&
                      (abs_dy < 12'd48);

    assign slash_hit = (abs_dx < 12'd42) &&
                       (abs_dy < 12'd42) &&
                       (((dx + dy) >= -12'sd2) && ((dx + dy) <= 12'sd2));

    assign spark_hit = ((abs_dx < 12'd3) && (abs_dy < (12'd22 + {7'd0, effect_age}))) ||
                       ((abs_dy < 12'd3) && (abs_dx < (12'd22 + {7'd0, effect_age})));

    always_comb begin
        unique case (effect_type)
            3'd0: begin left_texture_w = 7'd22; left_texture_h = 7'd22; right_texture_w = 7'd22; right_texture_h = 7'd22; end
            3'd1: begin left_texture_w = 7'd22; left_texture_h = 7'd22; right_texture_w = 7'd22; right_texture_h = 7'd22; end
            3'd2: begin left_texture_w = 7'd33; left_texture_h = 7'd29; right_texture_w = 7'd33; right_texture_h = 7'd29; end
            3'd3: begin left_texture_w = 7'd21; left_texture_h = 7'd20; right_texture_w = 7'd21; right_texture_h = 7'd20; end
            3'd4: begin left_texture_w = 7'd42; left_texture_h = 7'd17; right_texture_w = 7'd42; right_texture_h = 7'd17; end
            default: begin left_texture_w = 7'd22; left_texture_h = 7'd23; right_texture_w = 7'd22; right_texture_h = 7'd23; end
        endcase
    end

    assign left_sprite_w = (left_texture_w << 1) + left_texture_w;
    assign left_sprite_h = (left_texture_h << 1) + left_texture_h;
    assign right_sprite_w = (right_texture_w << 1) + right_texture_w;
    assign right_sprite_h = (right_texture_h << 1) + right_texture_h;
    assign left_inside = effect_active && (effect_type != FRUIT_BOMB) &&
                         (left_sprite_x_offset >= 12'sd0) &&
                         (left_sprite_y_offset >= 12'sd0) &&
                         (left_sprite_x_offset < $signed({5'd0, left_sprite_w})) &&
                         (left_sprite_y_offset < $signed({5'd0, left_sprite_h}));
    assign right_inside = effect_active && (effect_type != FRUIT_BOMB) &&
                          (right_sprite_x_offset >= 12'sd0) &&
                          (right_sprite_y_offset >= 12'sd0) &&
                          (right_sprite_x_offset < $signed({5'd0, right_sprite_w})) &&
                          (right_sprite_y_offset < $signed({5'd0, right_sprite_h}));
    assign left_sprite_x = div3(left_sprite_x_offset[6:0]);
    assign left_sprite_y = div3(left_sprite_y_offset[6:0]);
    assign right_sprite_x = div3(right_sprite_x_offset[6:0]);
    assign right_sprite_y = div3(right_sprite_y_offset[6:0]);
    assign fruit_halves_hit = (left_inside_q && left_pixel[8]) ||
                              (right_inside_q && right_pixel[8]);
    assign bomb_effect_hit = effect_active && (effect_type == FRUIT_BOMB) &&
                             (ring_hit || slash_hit || spark_hit);

    fruit_sprite_rom_dual half_rom (
        .clk              (clk),
        .fruit_type_a     (effect_type),
        .sprite_variant_a (2'd1),
        .sprite_x_a       (left_sprite_x),
        .sprite_y_a       (left_sprite_y),
        .sprite_pixel_a   (left_pixel),
        .fruit_type_b     (effect_type),
        .sprite_variant_b (2'd2),
        .sprite_x_b       (right_sprite_x),
        .sprite_y_b       (right_sprite_y),
        .sprite_pixel_b   (right_pixel)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            left_inside_q <= 1'b0;
            right_inside_q <= 1'b0;
        end else begin
            left_inside_q <= left_inside;
            right_inside_q <= right_inside;
        end
    end

    always_comb begin
        effect_hit = bomb_effect_hit || fruit_halves_hit;
        effect_r = 10'd0;
        effect_g = 10'd0;
        effect_b = 10'd0;

        if (bomb_effect_hit) begin
            effect_r = 10'h3FF;
            effect_g = 10'h080;
            effect_b = 10'h020;
        end else if (right_inside_q && right_pixel[8]) begin
            effect_r = {right_pixel[7:5], right_pixel[7:5], right_pixel[7:5], right_pixel[7]};
            effect_g = {right_pixel[4:2], right_pixel[4:2], right_pixel[4:2], right_pixel[4]};
            effect_b = {right_pixel[1:0], right_pixel[1:0], right_pixel[1:0], right_pixel[1:0], right_pixel[1:0]};
        end else if (left_inside_q && left_pixel[8]) begin
            effect_r = {left_pixel[7:5], left_pixel[7:5], left_pixel[7:5], left_pixel[7]};
            effect_g = {left_pixel[4:2], left_pixel[4:2], left_pixel[4:2], left_pixel[4]};
            effect_b = {left_pixel[1:0], left_pixel[1:0], left_pixel[1:0], left_pixel[1:0], left_pixel[1:0]};
        end
    end

endmodule

module knife_renderer (
    input  logic        clk,
    input  logic        reset,
    input  logic        knife_valid,
    input  logic [9:0]  knife_x,
    input  logic [9:0]  knife_y,
    input  logic [9:0]  draw_x,
    input  logic [9:0]  draw_y,
    input  logic [7:0]  bg_r,
    input  logic [7:0]  bg_g,
    input  logic [7:0]  bg_b,

    output logic [7:0]  out_r,
    output logic [7:0]  out_g,
    output logic [7:0]  out_b
);

    logic signed [11:0] draw_x_s;
    logic signed [11:0] draw_y_s;
    logic signed [11:0] knife_x_s;
    logic signed [11:0] knife_y_s;
    logic signed [11:0] dx;
    logic signed [11:0] dy;
    logic signed [11:0] sprite_x_offset;
    logic signed [11:0] sprite_y_offset;
    logic        inside_sprite;
    logic [5:0] sprite_x_next;
    logic [5:0] sprite_y_next;
    logic [5:0] sprite_x_q;
    logic [5:0] sprite_y_q;
    logic        inside_sprite_q;
    logic        inside_sprite_qq;
    logic [7:0]  bg_r_q;
    logic [7:0]  bg_g_q;
    logic [7:0]  bg_b_q;
    logic [7:0]  bg_r_qq;
    logic [7:0]  bg_g_qq;
    logic [7:0]  bg_b_qq;
    logic [8:0]  sprite_pixel;

    assign draw_x_s = $signed({2'b00, draw_x});
    assign draw_y_s = $signed({2'b00, draw_y});
    assign knife_x_s = $signed({2'b00, knife_x});
    assign knife_y_s = $signed({2'b00, knife_y});
    assign dx = draw_x_s - knife_x_s;
    assign dy = draw_y_s - knife_y_s;
    assign inside_sprite = knife_valid &&
                           (dx >= -12'sd24) &&
                           (dx < 12'sd24) &&
                           (dy >= -12'sd24) &&
                           (dy < 12'sd24);
    assign sprite_x_offset = dx + 12'sd24;
    assign sprite_y_offset = dy + 12'sd24;
    assign sprite_x_next = inside_sprite ? sprite_x_offset[5:0] : 6'd0;
    assign sprite_y_next = inside_sprite ? sprite_y_offset[5:0] : 6'd0;

    knife_sprite_rom knife_sprite_rom_inst (
        .clk          (clk),
        .sprite_x     (sprite_x_q),
        .sprite_y     (sprite_y_q),
        .sprite_pixel (sprite_pixel)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sprite_x_q <= 6'd0;
            sprite_y_q <= 6'd0;
            inside_sprite_q <= 1'b0;
            inside_sprite_qq <= 1'b0;
            bg_r_q <= 8'd0;
            bg_g_q <= 8'd0;
            bg_b_q <= 8'd0;
            bg_r_qq <= 8'd0;
            bg_g_qq <= 8'd0;
            bg_b_qq <= 8'd0;
            out_r <= 8'd0;
            out_g <= 8'd0;
            out_b <= 8'd0;
        end else begin
            sprite_x_q <= sprite_x_next;
            sprite_y_q <= sprite_y_next;
            inside_sprite_q <= inside_sprite;
            inside_sprite_qq <= inside_sprite_q;
            bg_r_q <= bg_r;
            bg_g_q <= bg_g;
            bg_b_q <= bg_b;

            bg_r_qq <= bg_r_q;
            bg_g_qq <= bg_g_q;
            bg_b_qq <= bg_b_q;

            if (inside_sprite_qq && sprite_pixel[8]) begin
                out_r <= {sprite_pixel[7:5], sprite_pixel[7:5], sprite_pixel[7:6]};
                out_g <= {sprite_pixel[4:2], sprite_pixel[4:2], sprite_pixel[4:3]};
                out_b <= {sprite_pixel[1:0], sprite_pixel[1:0], sprite_pixel[1:0], sprite_pixel[1:0]};
            end else begin
                out_r <= bg_r_qq;
                out_g <= bg_g_qq;
                out_b <= bg_b_qq;
            end
        end
    end

endmodule

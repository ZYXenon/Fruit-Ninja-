module fruit_renderer (
    input  logic               clk,
    input  logic               reset,
    input  logic               fruit_active,
    input  logic [2:0]         fruit_type,
    input  logic signed [11:0] fruit_x,
    input  logic signed [11:0] fruit_y,
    input  logic [9:0]         DrawX,
    input  logic [9:0]         DrawY,

    output logic               fruit_hit,
    output logic [9:0]         fruit_r,
    output logic [9:0]         fruit_g,
    output logic [9:0]         fruit_b
);

    logic signed [11:0] draw_x_s;
    logic signed [11:0] draw_y_s;
    logic signed [11:0] dx;
    logic signed [11:0] dy;
    logic inside_sprite;
    logic signed [11:0] sprite_left;
    logic signed [11:0] sprite_top;
    logic signed [11:0] sprite_x_offset;
    logic signed [11:0] sprite_y_offset;
    logic [6:0] sprite_x;
    logic [6:0] sprite_y;
    logic [6:0] sprite_w;
    logic [6:0] sprite_h;
    logic [6:0] texture_w;
    logic [6:0] texture_h;
    logic [8:0] sprite_pixel;
    logic inside_sprite_q;

    function automatic logic [6:0] div3(input logic [6:0] value);
        div3 = value / 7'd3;
    endfunction

    assign draw_x_s = $signed({2'b00, DrawX});
    assign draw_y_s = $signed({2'b00, DrawY});
    assign dx = draw_x_s - fruit_x;
    assign dy = draw_y_s - fruit_y;

    always_comb begin
        unique case (fruit_type)
            3'd0: begin texture_w = 7'd22; texture_h = 7'd22; end
            3'd1: begin texture_w = 7'd22; texture_h = 7'd22; end
            3'd2: begin texture_w = 7'd33; texture_h = 7'd29; end
            3'd3: begin texture_w = 7'd21; texture_h = 7'd20; end
            3'd4: begin texture_w = 7'd42; texture_h = 7'd17; end
            default: begin texture_w = 7'd22; texture_h = 7'd23; end
        endcase
    end

    assign sprite_w = (texture_w << 1) + texture_w;
    assign sprite_h = (texture_h << 1) + texture_h;
    assign sprite_left = fruit_x - $signed({5'd0, sprite_w[6:1]});
    assign sprite_top = fruit_y - $signed({5'd0, sprite_h[6:1]});
    assign sprite_x_offset = draw_x_s - sprite_left;
    assign sprite_y_offset = draw_y_s - sprite_top;
    assign inside_sprite = fruit_active &&
                           (sprite_x_offset >= 12'sd0) &&
                           (sprite_y_offset >= 12'sd0) &&
                           (sprite_x_offset < $signed({5'd0, sprite_w})) &&
                           (sprite_y_offset < $signed({5'd0, sprite_h}));
    assign sprite_x = div3(sprite_x_offset[6:0]);
    assign sprite_y = div3(sprite_y_offset[6:0]);

    fruit_sprite_rom fruit_sprite_rom_inst (
        .clk          (clk),
        .fruit_type   (fruit_type),
        .sprite_variant (2'd0),
        .sprite_x     (sprite_x),
        .sprite_y     (sprite_y),
        .sprite_pixel (sprite_pixel)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            inside_sprite_q <= 1'b0;
        end else begin
            inside_sprite_q <= inside_sprite;
        end
    end

    always_comb begin
        fruit_hit = inside_sprite_q && sprite_pixel[8];
        fruit_r   = 10'd0;
        fruit_g   = 10'd0;
        fruit_b   = 10'd0;

        if (fruit_hit) begin
            fruit_r = {sprite_pixel[7:5], sprite_pixel[7:5], sprite_pixel[7:5], sprite_pixel[7]};
            fruit_g = {sprite_pixel[4:2], sprite_pixel[4:2], sprite_pixel[4:2], sprite_pixel[4]};
            fruit_b = {sprite_pixel[1:0], sprite_pixel[1:0], sprite_pixel[1:0], sprite_pixel[1:0], sprite_pixel[1:0]};
        end
    end

endmodule

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

    localparam int TRAIL_LEN = 5;

    logic [9:0] trail_x [0:TRAIL_LEN-1];
    logic [9:0] trail_y [0:TRAIL_LEN-1];
    logic       trail_valid [0:TRAIL_LEN-1];

    logic signed [11:0] dx;
    logic signed [11:0] dy;
    logic [11:0] abs_dx;
    logic [11:0] abs_dy;
    logic [11:0] radius;
    logic [11:0] thickness;
    logic [11:0] diamond_metric;
    logic [11:0] slash_metric;

    function automatic logic [11:0] abs12(input logic signed [11:0] value);
        abs12 = value[11] ? $unsigned(-value) : $unsigned(value);
    endfunction

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < TRAIL_LEN; i = i + 1) begin
                trail_x[i] <= 10'd0;
                trail_y[i] <= 10'd0;
                trail_valid[i] <= 1'b0;
            end
        end else if (frame_tick) begin
            for (int i = TRAIL_LEN - 1; i > 0; i = i - 1) begin
                trail_x[i] <= trail_x[i - 1];
                trail_y[i] <= trail_y[i - 1];
                trail_valid[i] <= trail_valid[i - 1];
            end

            trail_x[0] <= knife_x;
            trail_y[0] <= knife_y;
            trail_valid[0] <= knife_valid;
        end
    end

    always_comb begin
        out_r = bg_r;
        out_g = bg_g;
        out_b = bg_b;

        for (int i = TRAIL_LEN - 1; i >= 0; i = i - 1) begin
            dx = $signed({2'b00, draw_x}) - $signed({2'b00, trail_x[i]});
            dy = $signed({2'b00, draw_y}) - $signed({2'b00, trail_y[i]});
            abs_dx = abs12(dx);
            abs_dy = abs12(dy);
            unique case (i)
                0: begin radius = 12'd22; thickness = 12'd4; end
                1: begin radius = 12'd20; thickness = 12'd5; end
                2: begin radius = 12'd18; thickness = 12'd6; end
                3: begin radius = 12'd16; thickness = 12'd7; end
                default: begin radius = 12'd14; thickness = 12'd8; end
            endcase
            diamond_metric = abs_dx + abs_dy;
            slash_metric = abs12(dx + dy);

            if (trail_valid[i] &&
                (diamond_metric < radius) &&
                (slash_metric < thickness)) begin
                unique case (i)
                    0: begin out_r = 8'hff; out_g = 8'he8; out_b = 8'h90; end
                    1: begin out_r = 8'he0; out_g = 8'hb8; out_b = 8'h70; end
                    2: begin out_r = 8'ha8; out_g = 8'h78; out_b = 8'h48; end
                    3: begin out_r = 8'h70; out_g = 8'h48; out_b = 8'h30; end
                    default: begin out_r = 8'h48; out_g = 8'h2c; out_b = 8'h20; end
                endcase
            end
        end
    end

endmodule

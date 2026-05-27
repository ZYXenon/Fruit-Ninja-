module ui_renderer (
    input  logic [9:0] DrawX,
    input  logic [9:0] DrawY,
    input  logic [1:0] game_state,
    input  logic [1:0] bomb_hits,

    input  logic [3:0] score_thousands,
    input  logic [3:0] score_hundreds,
    input  logic [3:0] score_tens,
    input  logic [3:0] score_ones,
    input  logic [3:0] time_tens,
    input  logic [3:0] time_ones,

    output logic       ui_hit,
    output logic [9:0] ui_r,
    output logic [9:0] ui_g,
    output logic [9:0] ui_b
);

    localparam logic [1:0] GAME_START   = 2'd0;
    localparam logic [1:0] GAME_PLAYING = 2'd1;
    localparam logic [1:0] GAME_OVER    = 2'd2;

    localparam int DIGIT_W = 18;
    localparam int DIGIT_H = 28;
    localparam int DIGIT_STEP = 22;
    localparam int TEXT_SCALE = 4;
    localparam int TEXT_CELL_W = 6;
    localparam int TEXT_CELL_H = 7;
    localparam int SHADOW_OFFSET = 3;

    localparam logic [5:0] CH_SPACE = 6'd0;
    localparam logic [5:0] CH_A = 6'd1;
    localparam logic [5:0] CH_C = 6'd2;
    localparam logic [5:0] CH_E = 6'd3;
    localparam logic [5:0] CH_F = 6'd4;
    localparam logic [5:0] CH_G = 6'd5;
    localparam logic [5:0] CH_I = 6'd6;
    localparam logic [5:0] CH_J = 6'd7;
    localparam logic [5:0] CH_K = 6'd8;
    localparam logic [5:0] CH_M = 6'd9;
    localparam logic [5:0] CH_N = 6'd10;
    localparam logic [5:0] CH_O = 6'd11;
    localparam logic [5:0] CH_P = 6'd12;
    localparam logic [5:0] CH_R = 6'd13;
    localparam logic [5:0] CH_S = 6'd14;
    localparam logic [5:0] CH_T = 6'd15;
    localparam logic [5:0] CH_U = 6'd16;
    localparam logic [5:0] CH_V = 6'd17;
    localparam logic [5:0] CH_Y = 6'd18;
    localparam logic [5:0] CH_1 = 6'd19;
    localparam logic [5:0] CH_2 = 6'd20;

    logic hud_bar;
    logic panel_hit;
    logic score_hit;
    logic timer_hit;
    logic separator_hit;
    logic life_empty_hit;
    logic life_full_hit;
    logic final_score_hit;
    logic text_hit;
    logic score_shadow_hit;
    logic timer_shadow_hit;
    logic final_score_shadow_hit;
    logic text_shadow_hit;
    logic shadow_hit;

    function automatic logic [6:0] segments_for_digit(input logic [3:0] digit);
        begin
            unique case (digit)
                4'd0: segments_for_digit = 7'b1111110;
                4'd1: segments_for_digit = 7'b0110000;
                4'd2: segments_for_digit = 7'b1101101;
                4'd3: segments_for_digit = 7'b1111001;
                4'd4: segments_for_digit = 7'b0110011;
                4'd5: segments_for_digit = 7'b1011011;
                4'd6: segments_for_digit = 7'b1011111;
                4'd7: segments_for_digit = 7'b1110000;
                4'd8: segments_for_digit = 7'b1111111;
                4'd9: segments_for_digit = 7'b1111011;
                default: segments_for_digit = 7'b0000001;
            endcase
        end
    endfunction

    function automatic logic digit_pixel(
        input logic [3:0] digit,
        input logic [9:0] x,
        input logic [9:0] y,
        input int origin_x,
        input int origin_y
    );
        logic [6:0] seg;
        int lx;
        int ly;
        logic a;
        logic b;
        logic c;
        logic d;
        logic e;
        logic f;
        logic g;
        begin
            lx = x - origin_x;
            ly = y - origin_y;
            seg = segments_for_digit(digit);

            a = seg[6] && (ly >= 0)  && (ly < 4)  && (lx >= 3)  && (lx < 15);
            b = seg[5] && (ly >= 3)  && (ly < 14) && (lx >= 14) && (lx < 18);
            c = seg[4] && (ly >= 14) && (ly < 25) && (lx >= 14) && (lx < 18);
            d = seg[3] && (ly >= 24) && (ly < 28) && (lx >= 3)  && (lx < 15);
            e = seg[2] && (ly >= 14) && (ly < 25) && (lx >= 0)  && (lx < 4);
            f = seg[1] && (ly >= 3)  && (ly < 14) && (lx >= 0)  && (lx < 4);
            g = seg[0] && (ly >= 12) && (ly < 16) && (lx >= 3)  && (lx < 15);

            digit_pixel = (x >= origin_x) && (x < origin_x + DIGIT_W) &&
                          (y >= origin_y) && (y < origin_y + DIGIT_H) &&
                          (a || b || c || d || e || f || g);
        end
    endfunction

    function automatic logic [4:0] glyph_row(input logic [5:0] ch, input logic [2:0] row);
        begin
            glyph_row = 5'b00000;

            unique case (ch)
                CH_A: unique case (row)
                    3'd0: glyph_row = 5'b01110; 3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001; 3'd3: glyph_row = 5'b11111;
                    3'd4: glyph_row = 5'b10001; 3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
                endcase
                CH_C: unique case (row)
                    3'd0: glyph_row = 5'b01111; 3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000; 3'd3: glyph_row = 5'b10000;
                    3'd4: glyph_row = 5'b10000; 3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b01111; default: glyph_row = 5'b00000;
                endcase
                CH_E: unique case (row)
                    3'd0: glyph_row = 5'b11111; 3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000; 3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10000; 3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
                endcase
                CH_F: unique case (row)
                    3'd0: glyph_row = 5'b11111; 3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000; 3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10000; 3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b10000; default: glyph_row = 5'b00000;
                endcase
                CH_G: unique case (row)
                    3'd0: glyph_row = 5'b01111; 3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000; 3'd3: glyph_row = 5'b10011;
                    3'd4: glyph_row = 5'b10001; 3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01111; default: glyph_row = 5'b00000;
                endcase
                CH_I: unique case (row)
                    3'd0: glyph_row = 5'b11111; 3'd1: glyph_row = 5'b00100;
                    3'd2: glyph_row = 5'b00100; 3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100; 3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
                endcase
                CH_J: unique case (row)
                    3'd0: glyph_row = 5'b00111; 3'd1: glyph_row = 5'b00010;
                    3'd2: glyph_row = 5'b00010; 3'd3: glyph_row = 5'b00010;
                    3'd4: glyph_row = 5'b10010; 3'd5: glyph_row = 5'b10010;
                    3'd6: glyph_row = 5'b01100; default: glyph_row = 5'b00000;
                endcase
                CH_K: unique case (row)
                    3'd0: glyph_row = 5'b10001; 3'd1: glyph_row = 5'b10010;
                    3'd2: glyph_row = 5'b10100; 3'd3: glyph_row = 5'b11000;
                    3'd4: glyph_row = 5'b10100; 3'd5: glyph_row = 5'b10010;
                    3'd6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
                endcase
                CH_M: unique case (row)
                    3'd0: glyph_row = 5'b10001; 3'd1: glyph_row = 5'b11011;
                    3'd2: glyph_row = 5'b10101; 3'd3: glyph_row = 5'b10101;
                    3'd4: glyph_row = 5'b10001; 3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
                endcase
                CH_N: unique case (row)
                    3'd0: glyph_row = 5'b10001; 3'd1: glyph_row = 5'b11001;
                    3'd2: glyph_row = 5'b10101; 3'd3: glyph_row = 5'b10011;
                    3'd4: glyph_row = 5'b10001; 3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
                endcase
                CH_O: unique case (row)
                    3'd0: glyph_row = 5'b01110; 3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001; 3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001; 3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                CH_P: unique case (row)
                    3'd0: glyph_row = 5'b11110; 3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001; 3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10000; 3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b10000; default: glyph_row = 5'b00000;
                endcase
                CH_R: unique case (row)
                    3'd0: glyph_row = 5'b11110; 3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001; 3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10100; 3'd5: glyph_row = 5'b10010;
                    3'd6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
                endcase
                CH_S: unique case (row)
                    3'd0: glyph_row = 5'b01111; 3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000; 3'd3: glyph_row = 5'b01110;
                    3'd4: glyph_row = 5'b00001; 3'd5: glyph_row = 5'b00001;
                    3'd6: glyph_row = 5'b11110; default: glyph_row = 5'b00000;
                endcase
                CH_T: unique case (row)
                    3'd0: glyph_row = 5'b11111; 3'd1: glyph_row = 5'b00100;
                    3'd2: glyph_row = 5'b00100; 3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100; 3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
                endcase
                CH_U: unique case (row)
                    3'd0: glyph_row = 5'b10001; 3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001; 3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001; 3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                CH_V: unique case (row)
                    3'd0: glyph_row = 5'b10001; 3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001; 3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001; 3'd5: glyph_row = 5'b01010;
                    3'd6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
                endcase
                CH_Y: unique case (row)
                    3'd0: glyph_row = 5'b10001; 3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b01010; 3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100; 3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
                endcase
                CH_1: unique case (row)
                    3'd0: glyph_row = 5'b00100; 3'd1: glyph_row = 5'b01100;
                    3'd2: glyph_row = 5'b00100; 3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100; 3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                CH_2: unique case (row)
                    3'd0: glyph_row = 5'b01110; 3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b00001; 3'd3: glyph_row = 5'b00010;
                    3'd4: glyph_row = 5'b00100; 3'd5: glyph_row = 5'b01000;
                    3'd6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
                endcase
                default: glyph_row = 5'b00000;
            endcase
        end
    endfunction

    function automatic logic [5:0] message_char(input logic [2:0] msg, input int index);
        begin
            message_char = CH_SPACE;

            unique case (msg)
                3'd0: unique case (index) // AR FRUIT NINJA
                    0: message_char = CH_A; 1: message_char = CH_R; 2: message_char = CH_SPACE;
                    3: message_char = CH_F; 4: message_char = CH_R; 5: message_char = CH_U;
                    6: message_char = CH_I; 7: message_char = CH_T; 8: message_char = CH_SPACE;
                    9: message_char = CH_N; 10: message_char = CH_I; 11: message_char = CH_N;
                    12: message_char = CH_J; 13: message_char = CH_A; default: message_char = CH_SPACE;
                endcase
                3'd1: unique case (index) // PRESS KEY1 TO START
                    0: message_char = CH_P; 1: message_char = CH_R; 2: message_char = CH_E;
                    3: message_char = CH_S; 4: message_char = CH_S; 5: message_char = CH_SPACE;
                    6: message_char = CH_K; 7: message_char = CH_E; 8: message_char = CH_Y;
                    9: message_char = CH_1; 10: message_char = CH_SPACE; 11: message_char = CH_T;
                    12: message_char = CH_O; 13: message_char = CH_SPACE; 14: message_char = CH_S;
                    15: message_char = CH_T; 16: message_char = CH_A; 17: message_char = CH_R;
                    18: message_char = CH_T; default: message_char = CH_SPACE;
                endcase
                3'd2: unique case (index) // GAME OVER
                    0: message_char = CH_G; 1: message_char = CH_A; 2: message_char = CH_M;
                    3: message_char = CH_E; 4: message_char = CH_SPACE; 5: message_char = CH_O;
                    6: message_char = CH_V; 7: message_char = CH_E; 8: message_char = CH_R;
                    default: message_char = CH_SPACE;
                endcase
                3'd3: unique case (index) // SCORE
                    0: message_char = CH_S; 1: message_char = CH_C; 2: message_char = CH_O;
                    3: message_char = CH_R; 4: message_char = CH_E; default: message_char = CH_SPACE;
                endcase
                3'd4: unique case (index) // KEY1 MENU
                    0: message_char = CH_K; 1: message_char = CH_E; 2: message_char = CH_Y;
                    3: message_char = CH_1; 4: message_char = CH_SPACE; 5: message_char = CH_M;
                    6: message_char = CH_E; 7: message_char = CH_N; 8: message_char = CH_U;
                    default: message_char = CH_SPACE;
                endcase
                3'd5: unique case (index) // KEY2 RETRY
                    0: message_char = CH_K; 1: message_char = CH_E; 2: message_char = CH_Y;
                    3: message_char = CH_2; 4: message_char = CH_SPACE; 5: message_char = CH_R;
                    6: message_char = CH_E; 7: message_char = CH_T; 8: message_char = CH_R;
                    9: message_char = CH_Y; default: message_char = CH_SPACE;
                endcase
                default: message_char = CH_SPACE;
            endcase
        end
    endfunction

    function automatic logic text_pixel(
        input logic [2:0] msg,
        input int msg_len,
        input logic [9:0] x,
        input logic [9:0] y,
        input int origin_x,
        input int origin_y
    );
        int rel_x;
        int rel_y;
        int char_index;
        int cell_x;
        int glyph_x;
        int glyph_y;
        logic [4:0] row_bits;
        begin
            text_pixel = 1'b0;

            if ((x >= origin_x) &&
                (x < origin_x + msg_len * TEXT_CELL_W * TEXT_SCALE) &&
                (y >= origin_y) &&
                (y < origin_y + TEXT_CELL_H * TEXT_SCALE)) begin
                rel_x = x - origin_x;
                rel_y = y - origin_y;
                char_index = rel_x / (TEXT_CELL_W * TEXT_SCALE);
                cell_x = (rel_x - char_index * TEXT_CELL_W * TEXT_SCALE) / TEXT_SCALE;
                glyph_x = cell_x;
                glyph_y = rel_y / TEXT_SCALE;

                if (glyph_x < 5) begin
                    row_bits = glyph_row(message_char(msg, char_index), glyph_y[2:0]);
                    text_pixel = row_bits[4 - glyph_x] ||
                                 ((glyph_x > 0) && row_bits[5 - glyph_x]);
                end
            end
        end
    endfunction

    assign hud_bar = (game_state == GAME_PLAYING) && (DrawY < 10'd44);
    assign panel_hit = ((game_state == GAME_START) || (game_state == GAME_OVER)) &&
                       (DrawX >= 10'd64) && (DrawX < 10'd576) &&
                       (DrawY >= 10'd96) && (DrawY < 10'd384);

    assign score_hit =
        (game_state == GAME_PLAYING) &&
        (digit_pixel(score_thousands, DrawX, DrawY, 24, 8) ||
         digit_pixel(score_hundreds,  DrawX, DrawY, 24 + DIGIT_STEP, 8) ||
         digit_pixel(score_tens,      DrawX, DrawY, 24 + 2 * DIGIT_STEP, 8) ||
         digit_pixel(score_ones,      DrawX, DrawY, 24 + 3 * DIGIT_STEP, 8));

    assign timer_hit =
        (game_state == GAME_PLAYING) &&
        (digit_pixel(time_tens, DrawX, DrawY, 540, 8) ||
         digit_pixel(time_ones, DrawX, DrawY, 540 + DIGIT_STEP, 8));

    assign separator_hit =
        (game_state == GAME_PLAYING) &&
        (((DrawX >= 10'd524) && (DrawX < 10'd528) && (DrawY >= 10'd14) && (DrawY < 10'd18)) ||
         ((DrawX >= 10'd524) && (DrawX < 10'd528) && (DrawY >= 10'd26) && (DrawY < 10'd30)));

    assign life_empty_hit =
        (game_state == GAME_PLAYING) &&
        (((DrawX >= 10'd284) && (DrawX < 10'd304) && (DrawY >= 10'd12) && (DrawY < 10'd32)) ||
         ((DrawX >= 10'd310) && (DrawX < 10'd330) && (DrawY >= 10'd12) && (DrawY < 10'd32)) ||
         ((DrawX >= 10'd336) && (DrawX < 10'd356) && (DrawY >= 10'd12) && (DrawY < 10'd32)));

    assign life_full_hit =
        (game_state == GAME_PLAYING) &&
        ((((bomb_hits < 2'd3) && (DrawX >= 10'd284) && (DrawX < 10'd304)) ||
          ((bomb_hits < 2'd2) && (DrawX >= 10'd310) && (DrawX < 10'd330)) ||
          ((bomb_hits < 2'd1) && (DrawX >= 10'd336) && (DrawX < 10'd356))) &&
         (DrawY >= 10'd12) && (DrawY < 10'd32));

    assign final_score_hit =
        (game_state == GAME_OVER) &&
        (digit_pixel(score_thousands, DrawX, DrawY, 276, 260) ||
         digit_pixel(score_hundreds,  DrawX, DrawY, 276 + DIGIT_STEP, 260) ||
         digit_pixel(score_tens,      DrawX, DrawY, 276 + 2 * DIGIT_STEP, 260) ||
         digit_pixel(score_ones,      DrawX, DrawY, 276 + 3 * DIGIT_STEP, 260));

    assign text_hit =
        ((game_state == GAME_START) &&
         (text_pixel(3'd0, 14, DrawX, DrawY, 152, 150) ||
          text_pixel(3'd1, 19, DrawX, DrawY, 92, 250))) ||
        ((game_state == GAME_OVER) &&
         (text_pixel(3'd2, 9,  DrawX, DrawY, 212, 130) ||
          text_pixel(3'd3, 5,  DrawX, DrawY, 260, 210) ||
          text_pixel(3'd4, 9,  DrawX, DrawY, 212, 320) ||
          text_pixel(3'd5, 10, DrawX, DrawY, 200, 352)));

    assign score_shadow_hit =
        (game_state == GAME_PLAYING) &&
        (digit_pixel(score_thousands, DrawX, DrawY, 24 + SHADOW_OFFSET, 8 + SHADOW_OFFSET) ||
         digit_pixel(score_hundreds,  DrawX, DrawY, 24 + DIGIT_STEP + SHADOW_OFFSET, 8 + SHADOW_OFFSET) ||
         digit_pixel(score_tens,      DrawX, DrawY, 24 + 2 * DIGIT_STEP + SHADOW_OFFSET, 8 + SHADOW_OFFSET) ||
         digit_pixel(score_ones,      DrawX, DrawY, 24 + 3 * DIGIT_STEP + SHADOW_OFFSET, 8 + SHADOW_OFFSET));

    assign timer_shadow_hit =
        (game_state == GAME_PLAYING) &&
        (digit_pixel(time_tens, DrawX, DrawY, 540 + SHADOW_OFFSET, 8 + SHADOW_OFFSET) ||
         digit_pixel(time_ones, DrawX, DrawY, 540 + DIGIT_STEP + SHADOW_OFFSET, 8 + SHADOW_OFFSET));

    assign final_score_shadow_hit =
        (game_state == GAME_OVER) &&
        (digit_pixel(score_thousands, DrawX, DrawY, 276 + SHADOW_OFFSET, 260 + SHADOW_OFFSET) ||
         digit_pixel(score_hundreds,  DrawX, DrawY, 276 + DIGIT_STEP + SHADOW_OFFSET, 260 + SHADOW_OFFSET) ||
         digit_pixel(score_tens,      DrawX, DrawY, 276 + 2 * DIGIT_STEP + SHADOW_OFFSET, 260 + SHADOW_OFFSET) ||
         digit_pixel(score_ones,      DrawX, DrawY, 276 + 3 * DIGIT_STEP + SHADOW_OFFSET, 260 + SHADOW_OFFSET));

    assign text_shadow_hit =
        ((game_state == GAME_START) &&
         (text_pixel(3'd0, 14, DrawX, DrawY, 152 + SHADOW_OFFSET, 150 + SHADOW_OFFSET) ||
          text_pixel(3'd1, 19, DrawX, DrawY, 92 + SHADOW_OFFSET, 250 + SHADOW_OFFSET))) ||
        ((game_state == GAME_OVER) &&
         (text_pixel(3'd2, 9,  DrawX, DrawY, 212 + SHADOW_OFFSET, 130 + SHADOW_OFFSET) ||
          text_pixel(3'd3, 5,  DrawX, DrawY, 260 + SHADOW_OFFSET, 210 + SHADOW_OFFSET) ||
          text_pixel(3'd4, 9,  DrawX, DrawY, 212 + SHADOW_OFFSET, 320 + SHADOW_OFFSET) ||
          text_pixel(3'd5, 10, DrawX, DrawY, 200 + SHADOW_OFFSET, 352 + SHADOW_OFFSET)));

    assign shadow_hit = (score_shadow_hit || timer_shadow_hit ||
                         final_score_shadow_hit || text_shadow_hit) &&
                        !(score_hit || timer_hit || final_score_hit || text_hit);

    always_comb begin
        ui_hit = hud_bar || panel_hit || score_hit || timer_hit ||
                 separator_hit || life_empty_hit || life_full_hit ||
                 final_score_hit || text_hit || shadow_hit;
        ui_r = 10'd0;
        ui_g = 10'd0;
        ui_b = 10'd0;

        if (hud_bar) begin
            ui_r = 10'h010;
            ui_g = 10'h018;
            ui_b = 10'h018;
        end

        if (panel_hit) begin
            ui_r = 10'h018;
            ui_g = 10'h018;
            ui_b = 10'h020;
        end

        if (shadow_hit) begin
            ui_r = 10'h030;
            ui_g = 10'h020;
            ui_b = 10'h018;
        end

        if (score_hit || final_score_hit) begin
            ui_r = 10'h3FF;
            ui_g = 10'h2E0;
            ui_b = 10'h060;
        end

        if (life_empty_hit) begin
            ui_r = 10'h120;
            ui_g = 10'h030;
            ui_b = 10'h030;
        end

        if (life_full_hit) begin
            ui_r = 10'h3FF;
            ui_g = 10'h050;
            ui_b = 10'h050;
        end

        if (timer_hit || separator_hit || text_hit) begin
            ui_r = 10'h3FF;
            ui_g = 10'h360;
            ui_b = 10'h180;
        end
    end

endmodule

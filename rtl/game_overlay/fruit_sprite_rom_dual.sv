module fruit_sprite_rom_dual (
    input  logic       clk,

    input  logic [2:0] fruit_type_a,
    input  logic [1:0] sprite_variant_a,
    input  logic [6:0] sprite_x_a,
    input  logic [6:0] sprite_y_a,
    output logic [8:0] sprite_pixel_a,

    input  logic [2:0] fruit_type_b,
    input  logic [1:0] sprite_variant_b,
    input  logic [6:0] sprite_x_b,
    input  logic [6:0] sprite_y_b,
    output logic [8:0] sprite_pixel_b
);

    localparam int ROM_DEPTH = 16384;

    (* ramstyle = "M9K, no_rw_check" *) logic [8:0] rom [0:ROM_DEPTH-1];

    function automatic logic [1:0] clamp_variant(input logic [1:0] sprite_variant);
        clamp_variant = (sprite_variant == 2'd3) ? 2'd0 : sprite_variant;
    endfunction

    function automatic logic [4:0] sprite_id_for(
        input logic [2:0] fruit_type,
        input logic [1:0] sprite_variant
    );
        logic [1:0] variant_clamped;
        begin
            variant_clamped = clamp_variant(sprite_variant);

            unique case (fruit_type)
                3'd0: sprite_id_for = 5'd0 + {3'd0, variant_clamped};
                3'd1: sprite_id_for = 5'd3 + {3'd0, variant_clamped};
                3'd2: sprite_id_for = 5'd6 + {3'd0, variant_clamped};
                3'd3: sprite_id_for = 5'd9 + {3'd0, variant_clamped};
                3'd4: sprite_id_for = 5'd12 + {3'd0, variant_clamped};
                default: sprite_id_for = 5'd15 + {3'd0, variant_clamped};
            endcase
        end
    endfunction

    function automatic logic [16:0] sprite_base_for(input logic [4:0] sprite_id);
        unique case (sprite_id)
            5'd0:  sprite_base_for = 17'd0;
            5'd1:  sprite_base_for = 17'd484;
            5'd2:  sprite_base_for = 17'd968;
            5'd3:  sprite_base_for = 17'd1452;
            5'd4:  sprite_base_for = 17'd1936;
            5'd5:  sprite_base_for = 17'd2420;
            5'd6:  sprite_base_for = 17'd2904;
            5'd7:  sprite_base_for = 17'd3861;
            5'd8:  sprite_base_for = 17'd4818;
            5'd9:  sprite_base_for = 17'd5775;
            5'd10: sprite_base_for = 17'd6195;
            5'd11: sprite_base_for = 17'd6615;
            5'd12: sprite_base_for = 17'd7035;
            5'd13: sprite_base_for = 17'd7749;
            5'd14: sprite_base_for = 17'd8463;
            5'd15: sprite_base_for = 17'd9177;
            5'd16: sprite_base_for = 17'd9683;
            default: sprite_base_for = 17'd10189;
        endcase
    endfunction

    function automatic logic [6:0] sprite_width_for(input logic [4:0] sprite_id);
        unique case (sprite_id)
            5'd6, 5'd7, 5'd8: sprite_width_for = 7'd33;
            5'd9, 5'd10, 5'd11: sprite_width_for = 7'd21;
            5'd12, 5'd13, 5'd14: sprite_width_for = 7'd42;
            default: sprite_width_for = 7'd22;
        endcase
    endfunction

    function automatic logic [6:0] sprite_height_for(input logic [4:0] sprite_id);
        unique case (sprite_id)
            5'd6, 5'd7, 5'd8: sprite_height_for = 7'd29;
            5'd9, 5'd10, 5'd11: sprite_height_for = 7'd20;
            5'd12, 5'd13, 5'd14: sprite_height_for = 7'd17;
            5'd15, 5'd16, 5'd17: sprite_height_for = 7'd23;
            default: sprite_height_for = 7'd22;
        endcase
    endfunction

    logic [4:0] sprite_id_a;
    logic [4:0] sprite_id_b;
    logic [16:0] sprite_base_a;
    logic [16:0] sprite_base_b;
    logic [6:0] sprite_width_a;
    logic [6:0] sprite_width_b;
    logic [6:0] sprite_height_a;
    logic [6:0] sprite_height_b;
    logic [16:0] rom_addr_a;
    logic [16:0] rom_addr_b;
    logic [13:0] safe_rom_addr_a;
    logic [13:0] safe_rom_addr_b;
    logic in_bounds_a;
    logic in_bounds_b;
    logic in_bounds_a_q;
    logic in_bounds_b_q;
    logic [8:0] sprite_pixel_a_raw;
    logic [8:0] sprite_pixel_b_raw;

    assign sprite_id_a = sprite_id_for(fruit_type_a, sprite_variant_a);
    assign sprite_id_b = sprite_id_for(fruit_type_b, sprite_variant_b);
    assign sprite_base_a = sprite_base_for(sprite_id_a);
    assign sprite_base_b = sprite_base_for(sprite_id_b);
    assign sprite_width_a = sprite_width_for(sprite_id_a);
    assign sprite_width_b = sprite_width_for(sprite_id_b);
    assign sprite_height_a = sprite_height_for(sprite_id_a);
    assign sprite_height_b = sprite_height_for(sprite_id_b);
    assign in_bounds_a = (sprite_x_a < sprite_width_a) && (sprite_y_a < sprite_height_a);
    assign in_bounds_b = (sprite_x_b < sprite_width_b) && (sprite_y_b < sprite_height_b);
    assign rom_addr_a = sprite_base_a + (sprite_y_a * sprite_width_a) + {10'd0, sprite_x_a};
    assign rom_addr_b = sprite_base_b + (sprite_y_b * sprite_width_b) + {10'd0, sprite_x_b};
    assign safe_rom_addr_a = in_bounds_a ? rom_addr_a[13:0] : 14'd0;
    assign safe_rom_addr_b = in_bounds_b ? rom_addr_b[13:0] : 14'd0;

    assign sprite_pixel_a = in_bounds_a_q ? sprite_pixel_a_raw : 9'd0;
    assign sprite_pixel_b = in_bounds_b_q ? sprite_pixel_b_raw : 9'd0;

    always_ff @(posedge clk) begin
        sprite_pixel_a_raw <= rom[safe_rom_addr_a];
        sprite_pixel_b_raw <= rom[safe_rom_addr_b];
        in_bounds_a_q <= in_bounds_a;
        in_bounds_b_q <= in_bounds_b;
    end

    initial begin
        $readmemh("fruit_sprites_thirdres_rgba332.mem", rom);
    end

endmodule

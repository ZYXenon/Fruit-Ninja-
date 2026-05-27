module fruit_sprite_rom (
    input  logic       clk,
    input  logic [2:0] fruit_type,
    input  logic [1:0] sprite_variant,
    input  logic [6:0] sprite_x,
    input  logic [6:0] sprite_y,

    output logic [8:0] sprite_pixel
);

    localparam int ROM_DEPTH = 16384;

    logic [1:0] variant_clamped;
    logic [4:0] sprite_id;
    logic [16:0] sprite_base;
    logic [6:0] sprite_width;
    logic [6:0] sprite_height;
    logic [16:0] row_offset;
    logic [16:0] rom_addr;
    logic [13:0] safe_rom_addr;
    logic in_bounds;
    logic in_bounds_q;
    logic [8:0] sprite_pixel_raw;
    (* ramstyle = "M9K, no_rw_check" *) logic [8:0] rom [0:ROM_DEPTH-1];

    assign variant_clamped = (sprite_variant == 2'd3) ? 2'd0 : sprite_variant;

    always_comb begin
        unique case (fruit_type)
            3'd0: sprite_id = 5'd0 + {3'd0, variant_clamped};
            3'd1: sprite_id = 5'd3 + {3'd0, variant_clamped};
            3'd2: sprite_id = 5'd6 + {3'd0, variant_clamped};
            3'd3: sprite_id = 5'd9 + {3'd0, variant_clamped};
            3'd4: sprite_id = 5'd12 + {3'd0, variant_clamped};
            default: sprite_id = 5'd15 + {3'd0, variant_clamped};
        endcase
    end

    always_comb begin
        unique case (sprite_id)
            5'd0:  begin sprite_base = 17'd0;     sprite_width = 7'd22; sprite_height = 7'd22; end
            5'd1:  begin sprite_base = 17'd484;   sprite_width = 7'd22; sprite_height = 7'd22; end
            5'd2:  begin sprite_base = 17'd968;   sprite_width = 7'd22; sprite_height = 7'd22; end
            5'd3:  begin sprite_base = 17'd1452;  sprite_width = 7'd22; sprite_height = 7'd22; end
            5'd4:  begin sprite_base = 17'd1936;  sprite_width = 7'd22; sprite_height = 7'd22; end
            5'd5:  begin sprite_base = 17'd2420;  sprite_width = 7'd22; sprite_height = 7'd22; end
            5'd6:  begin sprite_base = 17'd2904;  sprite_width = 7'd33; sprite_height = 7'd29; end
            5'd7:  begin sprite_base = 17'd3861;  sprite_width = 7'd33; sprite_height = 7'd29; end
            5'd8:  begin sprite_base = 17'd4818;  sprite_width = 7'd33; sprite_height = 7'd29; end
            5'd9:  begin sprite_base = 17'd5775;  sprite_width = 7'd21; sprite_height = 7'd20; end
            5'd10: begin sprite_base = 17'd6195;  sprite_width = 7'd21; sprite_height = 7'd20; end
            5'd11: begin sprite_base = 17'd6615;  sprite_width = 7'd21; sprite_height = 7'd20; end
            5'd12: begin sprite_base = 17'd7035;  sprite_width = 7'd42; sprite_height = 7'd17; end
            5'd13: begin sprite_base = 17'd7749;  sprite_width = 7'd42; sprite_height = 7'd17; end
            5'd14: begin sprite_base = 17'd8463;  sprite_width = 7'd42; sprite_height = 7'd17; end
            5'd15: begin sprite_base = 17'd9177;  sprite_width = 7'd22; sprite_height = 7'd23; end
            5'd16: begin sprite_base = 17'd9683;  sprite_width = 7'd22; sprite_height = 7'd23; end
            default: begin sprite_base = 17'd10189; sprite_width = 7'd22; sprite_height = 7'd23; end
        endcase
    end

    assign row_offset = sprite_y * sprite_width;
    assign rom_addr = sprite_base + row_offset + {10'd0, sprite_x};
    assign in_bounds = (sprite_x < sprite_width) && (sprite_y < sprite_height);
    assign safe_rom_addr = in_bounds ? rom_addr[13:0] : 14'd0;

    assign sprite_pixel = in_bounds_q ? sprite_pixel_raw : 9'd0;

    always_ff @(posedge clk) begin
        sprite_pixel_raw <= rom[safe_rom_addr];
        in_bounds_q <= in_bounds;
    end

    initial begin
        $readmemh("fruit_sprites_thirdres_rgba332.mem", rom);
    end

endmodule

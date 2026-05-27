module knife_sprite_rom (
    input  logic       clk,
    input  logic [5:0] sprite_x,
    input  logic [5:0] sprite_y,

    output logic [8:0] sprite_pixel
);

    localparam int SPRITE_SIZE = 48;
    localparam int ROM_DEPTH = SPRITE_SIZE * SPRITE_SIZE;

    logic [11:0] rom_addr;
    logic [11:0] sprite_x_ext;
    logic [11:0] sprite_y_ext;
    (* ramstyle = "M10K" *) logic [8:0] rom [0:ROM_DEPTH-1];

    assign sprite_x_ext = {6'd0, sprite_x};
    assign sprite_y_ext = {6'd0, sprite_y};
    assign rom_addr = (sprite_y_ext << 5) + (sprite_y_ext << 4) + sprite_x_ext;

    always_ff @(posedge clk) begin
        sprite_pixel <= rom[rom_addr];
    end

    initial begin
        $readmemh("knife_48x48_rgba332.mem", rom);
    end

endmodule

module background_rom (
    input  logic       clk,
    input  logic       reset,
    input  logic [9:0] draw_x,
    input  logic [9:0] draw_y,

    output logic [7:0] r8,
    output logic [7:0] g8,
    output logic [7:0] b8
);

    localparam int BG_W = 64;
    localparam int BG_H = 64;
    localparam int ROM_DEPTH = BG_W * BG_H;

    logic [5:0] bg_x;
    logic [5:0] bg_y;
    logic [11:0] row_base;
    logic [11:0] rom_addr;
    logic [7:0] pixel;
    (* ramstyle = "M9K, no_rw_check" *) logic [7:0] rom [0:ROM_DEPTH-1];

    assign bg_x = draw_x[5:0];
    assign bg_y = draw_y[5:0];
    assign row_base = {bg_y, 6'b0};
    assign rom_addr = row_base + {6'd0, bg_x};

    always_ff @(posedge clk) begin
        if (reset) begin
            pixel <= 8'h00;
        end else begin
            pixel <= rom[rom_addr];
        end
    end

    always_comb begin
        r8 = {pixel[7:5], pixel[7:5], pixel[7:6]};
        g8 = {pixel[4:2], pixel[4:2], pixel[4:3]};
        b8 = {pixel[1:0], pixel[1:0], pixel[1:0], pixel[1:0]};
    end

    initial begin
        $readmemh("background2_64x64_rgb332.mem", rom);
    end

endmodule

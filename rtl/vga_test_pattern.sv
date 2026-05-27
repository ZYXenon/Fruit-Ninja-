module vga_test_pattern (
    input  logic [9:0] draw_x,
    input  logic [9:0] draw_y,
    output logic [7:0] r,
    output logic [7:0] g,
    output logic [7:0] b
);

    always_comb begin
        if (draw_y >= 10'd480) begin
            r = 8'h00;
            g = 8'h00;
            b = 8'h00;
        end else if (draw_x < 10'd80) begin
            r = 8'hff;
            g = 8'hff;
            b = 8'hff;
        end else if (draw_x < 10'd160) begin
            r = 8'hff;
            g = 8'hff;
            b = 8'h00;
        end else if (draw_x < 10'd240) begin
            r = 8'h00;
            g = 8'hff;
            b = 8'hff;
        end else if (draw_x < 10'd320) begin
            r = 8'h00;
            g = 8'hff;
            b = 8'h00;
        end else if (draw_x < 10'd400) begin
            r = 8'hff;
            g = 8'h00;
            b = 8'hff;
        end else if (draw_x < 10'd480) begin
            r = 8'hff;
            g = 8'h00;
            b = 8'h00;
        end else if (draw_x < 10'd560) begin
            r = 8'h00;
            g = 8'h00;
            b = 8'hff;
        end else begin
            r = draw_x[7:0];
            g = draw_y[7:0];
            b = 8'h40;
        end
    end
endmodule

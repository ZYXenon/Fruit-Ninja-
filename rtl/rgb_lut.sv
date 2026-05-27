module rgb_lut (
    input  logic [15:0] rgb565,
    output logic [7:0]  r8,
    output logic [7:0]  g8,
    output logic [7:0]  b8
);

    logic [7:0] lut5 [0:31];
    logic [7:0] lut6 [0:63];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            lut5[i] = (i * 255) / 31;
        end

        for (i = 0; i < 64; i = i + 1) begin
            lut6[i] = (i * 255) / 63;
        end
    end

    assign r8 = lut5[rgb565[15:11]];
    assign g8 = lut6[rgb565[10:5]];
    assign b8 = lut5[rgb565[4:0]];
endmodule

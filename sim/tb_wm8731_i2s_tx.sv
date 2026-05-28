`timescale 1ns/1ps

module tb_wm8731_i2s_tx;
    logic bclk = 1'b0;
    logic reset = 1'b1;
    logic daclrck = 1'b1;
    logic signed [15:0] sample_left = 16'shA55A;
    logic signed [15:0] sample_right = 16'sh3CC3;
    logic dacdat;
    logic sample_tick;

    always #5 bclk = ~bclk;

    wm8731_i2s_tx dut (
        .bclk         (bclk),
        .reset        (reset),
        .daclrck      (daclrck),
        .sample_left  (sample_left),
        .sample_right (sample_right),
        .dacdat       (dacdat),
        .sample_tick  (sample_tick)
    );

    task automatic expect_channel(input logic lrck_value, input logic [15:0] expected, input logic expect_tick);
        integer bit_num;
        begin
            @(negedge bclk);
            #1;
            daclrck = lrck_value;

            @(posedge bclk);
            #1;
            assert(sample_tick == expect_tick)
                else $fatal(1, "sample_tick mismatch expected=%0b got=%0b", expect_tick, sample_tick);

            @(negedge bclk);
            #1;
            assert(dacdat == expected[15])
                else $fatal(1, "I2S MSB should be ready for the second BCLK rising edge after LRCK transition");

            for (bit_num = 14; bit_num >= 0; bit_num = bit_num - 1) begin
                @(negedge bclk);
                #1;
                assert(dacdat == expected[bit_num])
                    else $fatal(1, "I2S bit mismatch bit=%0d expected=%0b got=%0b",
                                bit_num, expected[bit_num], dacdat);
            end

            repeat (4) begin
                @(negedge bclk);
                #1;
                assert(dacdat == 1'b0)
                    else $fatal(1, "I2S padding should be zero after 16-bit word");
            end
        end
    endtask

    initial begin
        repeat (3) @(negedge bclk);
        reset = 1'b0;

        repeat (4) @(negedge bclk);

        expect_channel(1'b0, sample_left, 1'b0);

        sample_left = 16'sh1111;
        sample_right = 16'sh2222;
        expect_channel(1'b1, 16'sh3CC3, 1'b1);
        expect_channel(1'b0, 16'sh1111, 1'b0);

        $finish;
    end
endmodule

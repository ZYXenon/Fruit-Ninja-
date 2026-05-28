module wm8731_i2s_tx (
    input  logic              bclk,
    input  logic              reset,
    input  logic              daclrck,
    input  logic signed [15:0] sample_left,
    input  logic signed [15:0] sample_right,
    output logic              dacdat,
    output logic              sample_tick
);

    logic lrck_pos_d;
    logic lrck_neg_d;
    logic [4:0] bit_index;
    logic [15:0] shift_reg;
    logic [15:0] frame_right;
    logic sending_word;

    // I2S with WM8731 master clocks: LRCK low is left, LRCK high is right.
    // The codec changes LRCK after BCLK falling edge and samples DACDAT on BCLK rising edge.
    always_ff @(posedge bclk or posedge reset) begin
        if (reset) begin
            lrck_pos_d <= 1'b0;
            sample_tick <= 1'b0;
        end else begin
            lrck_pos_d <= daclrck;
            sample_tick <= !lrck_pos_d && daclrck;
        end
    end

    always_ff @(negedge bclk or posedge reset) begin
        if (reset) begin
            lrck_neg_d <= 1'b0;
            bit_index <= 5'd15;
            shift_reg <= 16'd0;
            frame_right <= 16'd0;
            sending_word <= 1'b0;
            dacdat <= 1'b0;
        end else begin
            lrck_neg_d <= daclrck;

            if (lrck_neg_d != daclrck) begin
                if (!daclrck) begin
                    shift_reg <= sample_left;
                    frame_right <= sample_right;
                    dacdat <= sample_left[15];
                end else begin
                    shift_reg <= frame_right;
                    dacdat <= frame_right[15];
                end
                sending_word <= 1'b1;
                bit_index <= 5'd14;
            end else if (sending_word) begin
                dacdat <= shift_reg[bit_index];
                if (bit_index != 5'd0) begin
                    bit_index <= bit_index - 5'd1;
                end else begin
                    sending_word <= 1'b0;
                end
            end else begin
                dacdat <= 1'b0;
            end
        end
    end

endmodule

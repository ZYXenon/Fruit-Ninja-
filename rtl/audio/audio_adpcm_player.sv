module audio_adpcm_player #(
    parameter int SAMPLE_COUNT = 1,
    parameter int BYTE_COUNT = 1,
    parameter int ADDR_WIDTH = 1,
    parameter int RATE_DIV = 12,
    parameter int ATTENUATE_SHIFT = 0,
    parameter bit LOOP = 1'b0,
    parameter int SAMPLE_INDEX_WIDTH = (SAMPLE_COUNT < 2) ? 1 : $clog2(SAMPLE_COUNT),
    parameter int RATE_WIDTH = (RATE_DIV < 2) ? 1 : $clog2(RATE_DIV)
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  sample_tick,
    input  logic                  enable,
    input  logic                  trigger,
    output logic [ADDR_WIDTH-1:0] rom_addr,
    input  logic [7:0]            rom_byte,
    output logic signed [15:0]    sample,
    output logic                  playing
);

    localparam logic [ADDR_WIDTH-1:0] ADDR_ONE = {{(ADDR_WIDTH-1){1'b0}}, 1'b1};

    logic [SAMPLE_INDEX_WIDTH-1:0] sample_index;
    logic [RATE_WIDTH-1:0] rate_count;
    logic signed [15:0] predictor;
    logic [6:0] step_index;
    logic [3:0] adpcm_code;
    logic signed [15:0] decoded_sample;
    logic [6:0] decoded_step_index;
    logic start_requested;
    logic playback_enabled;

    assign adpcm_code = sample_index[0] ? rom_byte[7:4] : rom_byte[3:0];
    assign playback_enabled = LOOP ? enable : 1'b1;
    assign start_requested = LOOP ? (enable && !playing) : (trigger && !playing);

    function automatic logic [15:0] ima_step(input logic [6:0] index);
        begin
            unique case (index)
                7'd0: ima_step = 16'd7;
                7'd1: ima_step = 16'd8;
                7'd2: ima_step = 16'd9;
                7'd3: ima_step = 16'd10;
                7'd4: ima_step = 16'd11;
                7'd5: ima_step = 16'd12;
                7'd6: ima_step = 16'd13;
                7'd7: ima_step = 16'd14;
                7'd8: ima_step = 16'd16;
                7'd9: ima_step = 16'd17;
                7'd10: ima_step = 16'd19;
                7'd11: ima_step = 16'd21;
                7'd12: ima_step = 16'd23;
                7'd13: ima_step = 16'd25;
                7'd14: ima_step = 16'd28;
                7'd15: ima_step = 16'd31;
                7'd16: ima_step = 16'd34;
                7'd17: ima_step = 16'd37;
                7'd18: ima_step = 16'd41;
                7'd19: ima_step = 16'd45;
                7'd20: ima_step = 16'd50;
                7'd21: ima_step = 16'd55;
                7'd22: ima_step = 16'd60;
                7'd23: ima_step = 16'd66;
                7'd24: ima_step = 16'd73;
                7'd25: ima_step = 16'd80;
                7'd26: ima_step = 16'd88;
                7'd27: ima_step = 16'd97;
                7'd28: ima_step = 16'd107;
                7'd29: ima_step = 16'd118;
                7'd30: ima_step = 16'd130;
                7'd31: ima_step = 16'd143;
                7'd32: ima_step = 16'd157;
                7'd33: ima_step = 16'd173;
                7'd34: ima_step = 16'd190;
                7'd35: ima_step = 16'd209;
                7'd36: ima_step = 16'd230;
                7'd37: ima_step = 16'd253;
                7'd38: ima_step = 16'd279;
                7'd39: ima_step = 16'd307;
                7'd40: ima_step = 16'd337;
                7'd41: ima_step = 16'd371;
                7'd42: ima_step = 16'd408;
                7'd43: ima_step = 16'd449;
                7'd44: ima_step = 16'd494;
                7'd45: ima_step = 16'd544;
                7'd46: ima_step = 16'd598;
                7'd47: ima_step = 16'd658;
                7'd48: ima_step = 16'd724;
                7'd49: ima_step = 16'd796;
                7'd50: ima_step = 16'd876;
                7'd51: ima_step = 16'd963;
                7'd52: ima_step = 16'd1060;
                7'd53: ima_step = 16'd1166;
                7'd54: ima_step = 16'd1282;
                7'd55: ima_step = 16'd1411;
                7'd56: ima_step = 16'd1552;
                7'd57: ima_step = 16'd1707;
                7'd58: ima_step = 16'd1878;
                7'd59: ima_step = 16'd2066;
                7'd60: ima_step = 16'd2272;
                7'd61: ima_step = 16'd2499;
                7'd62: ima_step = 16'd2749;
                7'd63: ima_step = 16'd3024;
                7'd64: ima_step = 16'd3327;
                7'd65: ima_step = 16'd3660;
                7'd66: ima_step = 16'd4026;
                7'd67: ima_step = 16'd4428;
                7'd68: ima_step = 16'd4871;
                7'd69: ima_step = 16'd5358;
                7'd70: ima_step = 16'd5894;
                7'd71: ima_step = 16'd6484;
                7'd72: ima_step = 16'd7132;
                7'd73: ima_step = 16'd7845;
                7'd74: ima_step = 16'd8630;
                7'd75: ima_step = 16'd9493;
                7'd76: ima_step = 16'd10442;
                7'd77: ima_step = 16'd11487;
                7'd78: ima_step = 16'd12635;
                7'd79: ima_step = 16'd13899;
                7'd80: ima_step = 16'd15289;
                7'd81: ima_step = 16'd16818;
                7'd82: ima_step = 16'd18500;
                7'd83: ima_step = 16'd20350;
                7'd84: ima_step = 16'd22385;
                7'd85: ima_step = 16'd24623;
                7'd86: ima_step = 16'd27086;
                7'd87: ima_step = 16'd29794;
                default: ima_step = 16'd32767;
            endcase
        end
    endfunction

    function automatic logic signed [15:0] clamp_s16(input logic signed [31:0] value);
        begin
            if (value > 32'sd32767) begin
                clamp_s16 = 16'sh7fff;
            end else if (value < -32'sd32768) begin
                clamp_s16 = 16'sh8000;
            end else begin
                clamp_s16 = value[15:0];
            end
        end
    endfunction

    function automatic logic signed [15:0] ima_decode_sample(
        input logic signed [15:0] current_predictor,
        input logic [6:0] current_index,
        input logic [3:0] code
    );
        logic [15:0] step;
        logic signed [31:0] diff;
        logic signed [31:0] next_value;
        begin
            step = ima_step(current_index);
            diff = {16'd0, step >> 3};
            if (code[0]) begin
                diff = diff + {16'd0, step >> 2};
            end
            if (code[1]) begin
                diff = diff + {16'd0, step >> 1};
            end
            if (code[2]) begin
                diff = diff + {16'd0, step};
            end

            next_value = {{16{current_predictor[15]}}, current_predictor};
            if (code[3]) begin
                next_value = next_value - diff;
            end else begin
                next_value = next_value + diff;
            end

            ima_decode_sample = clamp_s16(next_value);
        end
    endfunction

    function automatic logic [6:0] ima_next_index(
        input logic [6:0] current_index,
        input logic [3:0] code
    );
        logic signed [8:0] next_index;
        begin
            unique case (code[2:0])
                3'd4: next_index = {2'b00, current_index} + 9'sd2;
                3'd5: next_index = {2'b00, current_index} + 9'sd4;
                3'd6: next_index = {2'b00, current_index} + 9'sd6;
                3'd7: next_index = {2'b00, current_index} + 9'sd8;
                default: next_index = {2'b00, current_index} - 9'sd1;
            endcase

            if (next_index < 9'sd0) begin
                ima_next_index = 7'd0;
            end else if (next_index > 9'sd88) begin
                ima_next_index = 7'd88;
            end else begin
                ima_next_index = next_index[6:0];
            end
        end
    endfunction

    always_comb begin
        decoded_sample = ima_decode_sample(predictor, step_index, adpcm_code);
        decoded_step_index = ima_next_index(step_index, adpcm_code);
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sample_index <= '0;
            rate_count <= '0;
            predictor <= 16'sd0;
            step_index <= 7'd0;
            rom_addr <= '0;
            sample <= 16'sd0;
            playing <= 1'b0;
        end else begin
            if (LOOP && !enable) begin
                sample_index <= '0;
                rate_count <= '0;
                predictor <= 16'sd0;
                step_index <= 7'd0;
                rom_addr <= '0;
                sample <= 16'sd0;
                playing <= 1'b0;
            end else if (start_requested) begin
                sample_index <= '0;
                rate_count <= '0;
                predictor <= 16'sd0;
                step_index <= 7'd0;
                rom_addr <= '0;
                sample <= 16'sd0;
                playing <= 1'b1;
            end else if (sample_tick) begin
                if (playing && playback_enabled) begin
                    if (rate_count == (RATE_DIV - 1)) begin
                        rate_count <= '0;
                        predictor <= decoded_sample;
                        step_index <= decoded_step_index;
                        sample <= decoded_sample >>> ATTENUATE_SHIFT;

                        if (sample_index == (SAMPLE_COUNT - 1)) begin
                            if (LOOP && enable) begin
                                sample_index <= '0;
                                predictor <= 16'sd0;
                                step_index <= 7'd0;
                                rom_addr <= '0;
                            end else begin
                                playing <= 1'b0;
                            end
                        end else begin
                            sample_index <= sample_index + {{(SAMPLE_INDEX_WIDTH-1){1'b0}}, 1'b1};
                            if (sample_index[0]) begin
                                rom_addr <= rom_addr + ADDR_ONE;
                            end
                        end
                    end else begin
                        rate_count <= rate_count + {{(RATE_WIDTH-1){1'b0}}, 1'b1};
                    end
                end else begin
                    rate_count <= '0;
                    sample <= 16'sd0;
                end
            end
        end
    end
endmodule

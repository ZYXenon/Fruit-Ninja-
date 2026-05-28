module audio_mixer (
    input  logic        clk,
    input  logic        reset,
    input  logic        sample_tick,
    input  logic [1:0]  game_state,
    input  logic        effect_pulse,
    input  logic [2:0]  effect_type,
    output logic signed [15:0] sample_left,
    output logic signed [15:0] sample_right
);

`include "rtl/audio/audio_sample_params.svh"
`include "rtl/audio/audio_bomb_params.svh"
`include "rtl/audio/audio_background_params.svh"
`include "rtl/audio/audio_start_params.svh"

    localparam logic [1:0] GAME_START = 2'd0;
    localparam logic [1:0] GAME_PLAYING = 2'd1;
    localparam logic [2:0] FRUIT_BOMB = 3'd5;
    localparam int AUDIO_VOICE_COUNT = 4;
    localparam int ADPCM_RATE_DIV_4K = 12;

    logic slice_trigger;
    logic bomb_trigger;
    logic background_enable;
    logic start_trigger;
    logic [1:0] prev_game_state;
    logic slice_playing;
    logic [2:0] slice_active_voice_count;
    logic [`AUDIO_SLICE_ADDR_WIDTH-1:0] slice_addr;
    logic signed [15:0] slice_rom_sample;
    logic signed [15:0] slice_sample;
    logic bomb_playing;
    logic [2:0] bomb_active_voice_count;
    logic [`AUDIO_BOMB_ADDR_WIDTH-1:0] bomb_addr;
    logic signed [15:0] bomb_rom_sample;
    logic signed [15:0] bomb_sample;
    logic background_playing;
    logic [`AUDIO_BACKGROUND_ADDR_WIDTH-1:0] background_addr;
    logic [7:0] background_rom_byte;
    logic signed [15:0] background_sample;
    logic start_playing;
    logic [`AUDIO_START_ADDR_WIDTH-1:0] start_addr;
    logic [7:0] start_rom_byte;
    logic signed [15:0] start_sample;
    logic signed [15:0] effects_sample;
    logic signed [15:0] music_sample;
    logic signed [15:0] mixed_sample;

    assign slice_trigger = effect_pulse && (effect_type != FRUIT_BOMB);
    assign bomb_trigger = effect_pulse && (effect_type == FRUIT_BOMB);
    assign background_enable = (game_state == GAME_START);
    assign start_trigger = (prev_game_state != GAME_PLAYING) && (game_state == GAME_PLAYING);

    function automatic logic signed [15:0] saturating_add_s16(
        input logic signed [15:0] a,
        input logic signed [15:0] b
    );
        logic signed [16:0] sum;
        begin
            sum = {a[15], a} + {b[15], b};
            if (sum > 17'sd32767) begin
                saturating_add_s16 = 16'sh7fff;
            end else if (sum < -17'sd32768) begin
                saturating_add_s16 = 16'sh8000;
            end else begin
                saturating_add_s16 = sum[15:0];
            end
        end
    endfunction

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_game_state <= GAME_START;
        end else begin
            prev_game_state <= game_state;
        end
    end

    always_comb begin
        effects_sample = saturating_add_s16(slice_sample, bomb_sample);
        music_sample = saturating_add_s16(background_sample, start_sample);
        mixed_sample = saturating_add_s16(effects_sample, music_sample);
    end

    assign sample_left = mixed_sample;
    assign sample_right = mixed_sample;

    audio_sample_rom_slice slice_rom (
        .clk    (clk),
        .addr   (slice_addr),
        .sample (slice_rom_sample)
    );

    audio_poly_pcm_player #(
        .SAMPLE_COUNT (`AUDIO_SLICE_SAMPLE_COUNT),
        .ADDR_WIDTH   (`AUDIO_SLICE_ADDR_WIDTH),
        .VOICE_COUNT  (AUDIO_VOICE_COUNT)
    ) slice_player (
        .clk         (clk),
        .reset       (reset),
        .sample_tick (sample_tick),
        .trigger     (slice_trigger),
        .rom_addr    (slice_addr),
        .rom_sample  (slice_rom_sample),
        .sample      (slice_sample),
        .playing     (slice_playing),
        .active_voice_count (slice_active_voice_count)
    );

    audio_sample_rom_bomb bomb_rom (
        .clk    (clk),
        .addr   (bomb_addr),
        .sample (bomb_rom_sample)
    );

    audio_poly_pcm_player #(
        .SAMPLE_COUNT (`AUDIO_BOMB_SAMPLE_COUNT),
        .ADDR_WIDTH   (`AUDIO_BOMB_ADDR_WIDTH),
        .VOICE_COUNT  (AUDIO_VOICE_COUNT)
    ) bomb_player (
        .clk         (clk),
        .reset       (reset),
        .sample_tick (sample_tick),
        .trigger     (bomb_trigger),
        .rom_addr    (bomb_addr),
        .rom_sample  (bomb_rom_sample),
        .sample      (bomb_sample),
        .playing     (bomb_playing),
        .active_voice_count (bomb_active_voice_count)
    );

    audio_sample_rom_background background_rom (
        .clk         (clk),
        .addr        (background_addr),
        .sample_byte (background_rom_byte)
    );

    audio_adpcm_player #(
        .SAMPLE_COUNT    (`AUDIO_BACKGROUND_SAMPLE_COUNT),
        .BYTE_COUNT      (`AUDIO_BACKGROUND_BYTE_COUNT),
        .ADDR_WIDTH      (`AUDIO_BACKGROUND_ADDR_WIDTH),
        .RATE_DIV        (ADPCM_RATE_DIV_4K),
        .ATTENUATE_SHIFT (3),
        .LOOP            (1'b1)
    ) background_player (
        .clk         (clk),
        .reset       (reset),
        .sample_tick (sample_tick),
        .enable      (background_enable),
        .trigger     (1'b0),
        .rom_addr    (background_addr),
        .rom_byte    (background_rom_byte),
        .sample      (background_sample),
        .playing     (background_playing)
    );

    audio_sample_rom_start start_rom (
        .clk         (clk),
        .addr        (start_addr),
        .sample_byte (start_rom_byte)
    );

    audio_adpcm_player #(
        .SAMPLE_COUNT    (`AUDIO_START_SAMPLE_COUNT),
        .BYTE_COUNT      (`AUDIO_START_BYTE_COUNT),
        .ADDR_WIDTH      (`AUDIO_START_ADDR_WIDTH),
        .RATE_DIV        (ADPCM_RATE_DIV_4K),
        .ATTENUATE_SHIFT (2),
        .LOOP            (1'b0)
    ) start_player (
        .clk         (clk),
        .reset       (reset),
        .sample_tick (sample_tick),
        .enable      (1'b1),
        .trigger     (start_trigger),
        .rom_addr    (start_addr),
        .rom_byte    (start_rom_byte),
        .sample      (start_sample),
        .playing     (start_playing)
    );

    logic unused_playing;
    assign unused_playing = slice_playing || bomb_playing ||
                            (|slice_active_voice_count) ||
                            (|bomb_active_voice_count) ||
                            background_playing || start_playing;

endmodule

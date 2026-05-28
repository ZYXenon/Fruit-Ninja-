module audio_top (
    input  logic        clk_50,
    input  logic        reset,
    input  logic [31:0] effect_event_pio,
    input  logic [31:0] game_ctrl_pio,
    input  logic        aud_bclk,
    input  logic        aud_daclrck,
    output logic        aud_xck,
    output logic        aud_dacdat,
    output logic        audio_pll_locked
);

    logic audio_reset;
    logic sample_tick;
    logic [1:0] game_state_audio;
    logic effect_pulse_audio;
    logic [2:0] effect_type_audio;
    logic signed [15:0] sample_left;
    logic signed [15:0] sample_right;

    audio_clock_gen clock_gen (
        .clk_50    (clk_50),
        .reset     (reset),
        .audio_xck (aud_xck),
        .locked    (audio_pll_locked)
    );

    assign audio_reset = reset || !audio_pll_locked;

    audio_event_sync event_sync (
        .clk              (aud_bclk),
        .reset            (audio_reset),
        .effect_event_pio (effect_event_pio),
        .game_ctrl_pio    (game_ctrl_pio),
        .game_state       (game_state_audio),
        .effect_pulse     (effect_pulse_audio),
        .effect_type      (effect_type_audio)
    );

    audio_mixer mixer (
        .clk          (aud_bclk),
        .reset        (audio_reset),
        .sample_tick  (sample_tick),
        .game_state   (game_state_audio),
        .effect_pulse (effect_pulse_audio),
        .effect_type  (effect_type_audio),
        .sample_left  (sample_left),
        .sample_right (sample_right)
    );

    wm8731_i2s_tx i2s_tx (
        .bclk         (aud_bclk),
        .reset        (audio_reset),
        .daclrck      (aud_daclrck),
        .sample_left  (sample_left),
        .sample_right (sample_right),
        .dacdat       (aud_dacdat),
        .sample_tick  (sample_tick)
    );

endmodule

module audio_event_sync (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] effect_event_pio,
    input  logic [31:0] game_ctrl_pio,
    output logic [1:0]  game_state,
    output logic        effect_pulse,
    output logic [2:0]  effect_type
);

    logic [31:0] effect_meta;
    logic [31:0] effect_sync;
    logic [31:0] game_meta;
    logic [31:0] game_sync;
    logic        effect_toggle_d;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            effect_meta <= 32'd0;
            effect_sync <= 32'd0;
            game_meta <= 32'd0;
            game_sync <= 32'd0;
            effect_toggle_d <= 1'b0;
            effect_pulse <= 1'b0;
            effect_type <= 3'd0;
            game_state <= 2'd0;
        end else begin
            effect_meta <= effect_event_pio;
            effect_sync <= effect_meta;
            game_meta <= game_ctrl_pio;
            game_sync <= game_meta;

            effect_pulse <= effect_sync[31] ^ effect_toggle_d;
            effect_toggle_d <= effect_sync[31];
            effect_type <= effect_sync[28:26];
            game_state <= game_sync[29:28];
        end
    end

endmodule

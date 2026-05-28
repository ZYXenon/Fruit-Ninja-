`timescale 1ns/1ps

module tb_audio_event_sync;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] effect_event_pio = 32'd0;
    logic [31:0] game_ctrl_pio = 32'd0;
    logic [1:0] game_state;
    logic effect_pulse;
    logic [2:0] effect_type;

    always #10 clk = ~clk;

    audio_event_sync dut (
        .clk              (clk),
        .reset            (reset),
        .effect_event_pio (effect_event_pio),
        .game_ctrl_pio    (game_ctrl_pio),
        .game_state       (game_state),
        .effect_pulse     (effect_pulse),
        .effect_type      (effect_type)
    );

    initial begin
        repeat (3) @(posedge clk);
        reset = 1'b0;

        game_ctrl_pio[29:28] = 2'd1;
        repeat (4) @(posedge clk);
        #1;
        assert(game_state == 2'd1)
            else $fatal(1, "game state did not synchronize into audio clock domain");

        effect_event_pio = (32'h1 << 31) | (32'h3 << 26);
        repeat (3) @(posedge clk);
        #1;
        assert(effect_pulse && effect_type == 3'd3)
            else $fatal(1, "effect toggle should produce one pulse with synchronized type");

        @(posedge clk);
        #1;
        assert(!effect_pulse)
            else $fatal(1, "effect pulse should last exactly one audio clock");

        effect_event_pio = (32'h5 << 26);
        repeat (3) @(posedge clk);
        #1;
        assert(effect_pulse && effect_type == 3'd5)
            else $fatal(1, "second effect toggle should produce bomb effect pulse");

        $finish;
    end
endmodule

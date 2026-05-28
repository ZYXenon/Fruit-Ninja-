`timescale 1ns/1ps

module tb_audio_poly_pcm_player;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic sample_tick = 1'b0;
    logic trigger = 1'b0;
    logic [2:0] rom_addr;
    logic signed [15:0] rom_sample;
    logic signed [15:0] sample;
    logic playing;
    logic [2:0] active_voice_count;

    logic signed [15:0] rom [0:7];

    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        rom_sample <= rom[rom_addr];
    end

    audio_poly_pcm_player #(
        .SAMPLE_COUNT (8),
        .ADDR_WIDTH   (3),
        .VOICE_COUNT  (4),
        .ROM_LATENCY  (2),
        .ATTENUATE_SHIFT (0)
    ) dut (
        .clk                (clk),
        .reset              (reset),
        .sample_tick        (sample_tick),
        .trigger            (trigger),
        .rom_addr           (rom_addr),
        .rom_sample         (rom_sample),
        .sample             (sample),
        .playing            (playing),
        .active_voice_count (active_voice_count)
    );

    task automatic pulse_trigger;
        begin
            @(negedge clk);
            trigger = 1'b1;
            @(negedge clk);
            trigger = 1'b0;
        end
    endtask

    task automatic pulse_sample_tick;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
            #1;
        end
    endtask

    initial begin
        rom[0] = 16'sd4000;
        rom[1] = 16'sd8000;
        rom[2] = 16'sd12000;
        rom[3] = 16'sd16000;
        rom[4] = 16'sd20000;
        rom[5] = 16'sd24000;
        rom[6] = 16'sd28000;
        rom[7] = 16'sd32000;

        repeat (3) @(negedge clk);
        reset = 1'b0;

        pulse_trigger();
        pulse_trigger();
        pulse_trigger();
        pulse_trigger();
        repeat (40) @(negedge clk);

        assert(playing && active_voice_count == 3'd4)
            else $fatal(1, "four triggers should occupy four voices");

        pulse_sample_tick();
        assert(sample == 16'sd16000)
            else $fatal(1, "four voices at addr0 should mix to 16000, got %0d", sample);

        repeat (40) @(negedge clk);
        pulse_trigger();
        repeat (40) @(negedge clk);

        assert(playing && active_voice_count == 3'd4)
            else $fatal(1, "fifth trigger should steal oldest voice, not add a fifth");

        pulse_sample_tick();
        assert(sample == 16'sd28000)
            else $fatal(1, "stolen voice at addr0 plus three addr1 voices should mix to 28000, got %0d", sample);

        @(negedge clk);
        reset = 1'b1;
        rom[0] = 16'sd20000;
        repeat (3) @(negedge clk);
        reset = 1'b0;

        pulse_trigger();
        pulse_trigger();
        pulse_trigger();
        pulse_trigger();
        repeat (40) @(negedge clk);
        pulse_sample_tick();
        assert(sample == 16'sh7fff)
            else $fatal(1, "four loud voices should saturate positive, got %0d", sample);

        $finish;
    end
endmodule

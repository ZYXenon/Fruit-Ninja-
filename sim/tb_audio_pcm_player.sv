`timescale 1ns/1ps

module tb_audio_pcm_player;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic sample_tick = 1'b0;
    logic trigger = 1'b0;
    logic [1:0] rom_addr;
    logic signed [15:0] rom_sample;
    logic signed [15:0] sample;
    logic playing;

    always #5 clk = ~clk;

    always_comb begin
        case (rom_addr)
            2'd0: rom_sample = 16'sh1000;
            2'd1: rom_sample = -16'sh2000;
            2'd2: rom_sample = 16'sh3000;
            default: rom_sample = -16'sh4000;
        endcase
    end

    audio_pcm_player #(
        .SAMPLE_COUNT (4),
        .ADDR_WIDTH   (2)
    ) dut (
        .clk         (clk),
        .reset       (reset),
        .sample_tick (sample_tick),
        .trigger     (trigger),
        .rom_addr    (rom_addr),
        .rom_sample  (rom_sample),
        .sample      (sample),
        .playing     (playing)
    );

    task automatic tick_sample;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
            #1;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        trigger = 1'b1;
        @(negedge clk);
        trigger = 1'b0;
        #1;
        assert(playing && rom_addr == 2'd0)
            else $fatal(1, "trigger should start playback at address 0");

        tick_sample();
        assert(sample == 16'sh0400 && rom_addr == 2'd1)
            else $fatal(1, "first sample/address mismatch");

        @(negedge clk);
        trigger = 1'b1;
        @(negedge clk);
        trigger = 1'b0;
        #1;
        assert(playing && rom_addr == 2'd1)
            else $fatal(1, "trigger while playing should be ignored");

        tick_sample();
        assert(sample == -16'sh0800 && rom_addr == 2'd2)
            else $fatal(1, "second sample/address mismatch");

        tick_sample();
        assert(sample == 16'sh0c00 && rom_addr == 2'd3)
            else $fatal(1, "third sample/address mismatch");

        tick_sample();
        assert(!playing && sample == 16'sd0)
            else $fatal(1, "player should stop and output silence after final sample");

        @(negedge clk);
        trigger = 1'b1;
        @(negedge clk);
        trigger = 1'b0;
        tick_sample();
        assert(sample == 16'sh0400)
            else $fatal(1, "retrigger should restart playback");

        $finish;
    end
endmodule

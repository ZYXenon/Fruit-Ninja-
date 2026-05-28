module audio_pcm_player #(
    parameter int SAMPLE_COUNT = 1,
    parameter int ADDR_WIDTH = 1
) (
    input  logic                    clk,
    input  logic                    reset,
    input  logic                    sample_tick,
    input  logic                    trigger,
    output logic [ADDR_WIDTH-1:0]   rom_addr,
    input  logic signed [15:0]      rom_sample,
    output logic signed [15:0]      sample,
    output logic                    playing
);

    localparam logic [ADDR_WIDTH-1:0] LAST_ADDR = SAMPLE_COUNT - 1;
    localparam logic [ADDR_WIDTH-1:0] ADDR_ONE = {{(ADDR_WIDTH-1){1'b0}}, 1'b1};

    logic [ADDR_WIDTH-1:0] play_addr;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            play_addr <= '0;
            rom_addr <= '0;
            sample <= 16'sd0;
            playing <= 1'b0;
        end else begin
            if (trigger && !playing) begin
                play_addr <= '0;
                rom_addr <= '0;
                playing <= 1'b1;
            end else if (sample_tick) begin
                if (playing) begin
                    sample <= rom_sample >>> 2;

                    if (play_addr == LAST_ADDR) begin
                        playing <= 1'b0;
                        sample <= 16'sd0;
                    end else begin
                        play_addr <= play_addr + ADDR_ONE;
                        rom_addr <= play_addr + ADDR_ONE;
                    end
                end else begin
                    sample <= 16'sd0;
                    rom_addr <= '0;
                end
            end
        end
    end

endmodule

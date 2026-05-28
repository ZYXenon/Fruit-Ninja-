module audio_poly_pcm_player #(
    parameter int SAMPLE_COUNT = 1,
    parameter int ADDR_WIDTH = 1,
    parameter int VOICE_COUNT = 4,
    parameter int ROM_LATENCY = 2,
    parameter int ATTENUATE_SHIFT = 2,
    parameter int COUNT_WIDTH = (VOICE_COUNT < 2) ? 1 : $clog2(VOICE_COUNT + 1)
) (
    input  logic                    clk,
    input  logic                    reset,
    input  logic                    sample_tick,
    input  logic                    trigger,
    output logic [ADDR_WIDTH-1:0]   rom_addr,
    input  logic signed [15:0]      rom_sample,
    output logic signed [15:0]      sample,
    output logic                    playing,
    output logic [COUNT_WIDTH-1:0]  active_voice_count
);

    localparam logic [ADDR_WIDTH-1:0] LAST_ADDR = SAMPLE_COUNT - 1;
    localparam logic [ADDR_WIDTH-1:0] ADDR_ONE = {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
    localparam int VOICE_INDEX_WIDTH = (VOICE_COUNT < 2) ? 1 : $clog2(VOICE_COUNT);
    localparam int AGE_WIDTH = 16;
    localparam int WAIT_WIDTH = (ROM_LATENCY < 2) ? 1 : $clog2(ROM_LATENCY + 1);

    typedef enum logic [1:0] {
        S_ISSUE,
        S_WAIT,
        S_CAPTURE
    } scheduler_state_t;

    logic [VOICE_COUNT-1:0] voice_active;
    logic [ADDR_WIDTH-1:0] voice_addr [0:VOICE_COUNT-1];
    logic signed [15:0] voice_sample [0:VOICE_COUNT-1];
    logic [AGE_WIDTH-1:0] voice_age [0:VOICE_COUNT-1];
    logic [AGE_WIDTH-1:0] age_counter;

    scheduler_state_t scheduler_state;
    logic [VOICE_INDEX_WIDTH-1:0] scan_index;
    logic [VOICE_INDEX_WIDTH-1:0] pending_index;
    logic [AGE_WIDTH-1:0] pending_age;
    logic [ADDR_WIDTH-1:0] pending_addr;
    logic [WAIT_WIDTH-1:0] wait_count;

    logic have_free_voice;
    logic [VOICE_INDEX_WIDTH-1:0] free_index;
    logic [VOICE_INDEX_WIDTH-1:0] oldest_index;
    logic [VOICE_INDEX_WIDTH-1:0] trigger_index;
    logic [AGE_WIDTH-1:0] oldest_age;
    logic signed [15:0] mixed_next;

    integer comb_i;
    integer seq_i;

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

    always_comb begin
        have_free_voice = 1'b0;
        free_index = '0;
        oldest_index = '0;
        oldest_age = voice_age[0];
        active_voice_count = '0;
        mixed_next = 16'sd0;

        for (comb_i = 0; comb_i < VOICE_COUNT; comb_i = comb_i + 1) begin
            if (!voice_active[comb_i] && !have_free_voice) begin
                have_free_voice = 1'b1;
                free_index = comb_i[VOICE_INDEX_WIDTH-1:0];
            end

            if (voice_active[comb_i]) begin
                active_voice_count = active_voice_count + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
                mixed_next = saturating_add_s16(mixed_next, voice_sample[comb_i]);
            end

            if (voice_age[comb_i] < oldest_age) begin
                oldest_age = voice_age[comb_i];
                oldest_index = comb_i[VOICE_INDEX_WIDTH-1:0];
            end
        end

        trigger_index = have_free_voice ? free_index : oldest_index;
    end

    assign playing = |voice_active;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (seq_i = 0; seq_i < VOICE_COUNT; seq_i = seq_i + 1) begin
                voice_active[seq_i] <= 1'b0;
                voice_addr[seq_i] <= '0;
                voice_sample[seq_i] <= 16'sd0;
                voice_age[seq_i] <= '0;
            end

            age_counter <= '0;
            scheduler_state <= S_ISSUE;
            scan_index <= '0;
            pending_index <= '0;
            pending_age <= '0;
            pending_addr <= '0;
            wait_count <= '0;
            rom_addr <= '0;
            sample <= 16'sd0;
        end else begin
            if (sample_tick) begin
                sample <= mixed_next;
                scheduler_state <= S_ISSUE;
                scan_index <= '0;
                wait_count <= '0;

                for (seq_i = 0; seq_i < VOICE_COUNT; seq_i = seq_i + 1) begin
                    if (voice_active[seq_i]) begin
                        if (voice_addr[seq_i] == LAST_ADDR) begin
                            voice_active[seq_i] <= 1'b0;
                            voice_addr[seq_i] <= '0;
                            voice_sample[seq_i] <= 16'sd0;
                        end else begin
                            voice_addr[seq_i] <= voice_addr[seq_i] + ADDR_ONE;
                        end
                    end
                end
            end else begin
                unique case (scheduler_state)
                    S_ISSUE: begin
                        pending_index <= scan_index;
                        pending_age <= voice_age[scan_index];
                        pending_addr <= voice_addr[scan_index];
                        rom_addr <= voice_active[scan_index] ? voice_addr[scan_index] : '0;
                        wait_count <= ROM_LATENCY;
                        scheduler_state <= S_WAIT;
                    end

                    S_WAIT: begin
                        if (wait_count == '0) begin
                            scheduler_state <= S_CAPTURE;
                        end else begin
                            wait_count <= wait_count - {{(WAIT_WIDTH-1){1'b0}}, 1'b1};
                        end
                    end

                    default: begin
                        if (voice_active[pending_index] &&
                            (voice_age[pending_index] == pending_age) &&
                            (voice_addr[pending_index] == pending_addr)) begin
                            voice_sample[pending_index] <= rom_sample >>> ATTENUATE_SHIFT;
                        end

                        if (scan_index == VOICE_COUNT - 1) begin
                            scan_index <= '0;
                        end else begin
                            scan_index <= scan_index + {{(VOICE_INDEX_WIDTH-1){1'b0}}, 1'b1};
                        end

                        scheduler_state <= S_ISSUE;
                    end
                endcase
            end

            if (trigger) begin
                voice_active[trigger_index] <= 1'b1;
                voice_addr[trigger_index] <= '0;
                voice_sample[trigger_index] <= 16'sd0;
                voice_age[trigger_index] <= age_counter + {{(AGE_WIDTH-1){1'b0}}, 1'b1};
                age_counter <= age_counter + {{(AGE_WIDTH-1){1'b0}}, 1'b1};
            end
        end
    end

endmodule

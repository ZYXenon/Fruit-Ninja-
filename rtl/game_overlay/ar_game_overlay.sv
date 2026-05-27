module ar_game_overlay (
    input  logic        clk,
    input  logic        reset,

    input  logic [9:0]  draw_x,
    input  logic [9:0]  draw_y,
    input  logic        blank_n,

    input  logic [7:0]  bg_r,
    input  logic [7:0]  bg_g,
    input  logic [7:0]  bg_b,

    input  logic [31:0] game_ctrl_pio,
    input  logic [31:0] fruit0_desc_pio,
    input  logic [31:0] fruit1_desc_pio,
    input  logic [31:0] fruit2_desc_pio,
    input  logic [31:0] fruit3_desc_pio,
    input  logic [31:0] effect_event_pio,

    output logic [7:0]  out_r,
    output logic [7:0]  out_g,
    output logic [7:0]  out_b
);

    localparam int MAX_FRUITS = 4;

    logic [7:0] next_r;
    logic [7:0] next_g;
    logic [7:0] next_b;

    logic [2:0] commit_sync;
    logic [2:0] effect_sync;
    logic       commit_pulse;
    logic       effect_pulse;

    logic        overlay_enable;
    logic [1:0]  game_state;
    logic [1:0]  bomb_hits;
    logic [13:0] score_value;
    logic [3:0]  time_tens;
    logic [3:0]  time_ones;
    logic [15:0] score_bcd;

    logic [MAX_FRUITS-1:0] fruit_active;
    logic [2:0] fruit_type [0:MAX_FRUITS-1];
    logic signed [11:0] fruit_x [0:MAX_FRUITS-1];
    logic signed [11:0] fruit_y [0:MAX_FRUITS-1];

    logic [MAX_FRUITS-1:0] fruit_hit;
    logic [9:0] fruit_r [0:MAX_FRUITS-1];
    logic [9:0] fruit_g [0:MAX_FRUITS-1];
    logic [9:0] fruit_b [0:MAX_FRUITS-1];

    logic [MAX_FRUITS-1:0] effect_start;
    logic [MAX_FRUITS-1:0] effect_active;
    logic [MAX_FRUITS-1:0] effect_hit;
    logic [2:0] effect_type [0:MAX_FRUITS-1];
    logic signed [11:0] effect_x [0:MAX_FRUITS-1];
    logic signed [11:0] effect_y [0:MAX_FRUITS-1];
    logic [4:0] effect_age [0:MAX_FRUITS-1];
    logic [9:0] effect_r [0:MAX_FRUITS-1];
    logic [9:0] effect_g [0:MAX_FRUITS-1];
    logic [9:0] effect_b [0:MAX_FRUITS-1];

    logic signed [11:0] effect_event_x;
    logic signed [11:0] effect_event_y;

    logic ui_hit;
    logic [9:0] ui_r;
    logic [9:0] ui_g;
    logic [9:0] ui_b;

    function automatic logic [15:0] bin_to_bcd4(input logic [13:0] bin);
        integer i;
        logic [29:0] shift;
        begin
            shift = 30'd0;
            shift[13:0] = bin;

            for (i = 0; i < 14; i = i + 1) begin
                if (shift[17:14] >= 4'd5) shift[17:14] = shift[17:14] + 4'd3;
                if (shift[21:18] >= 4'd5) shift[21:18] = shift[21:18] + 4'd3;
                if (shift[25:22] >= 4'd5) shift[25:22] = shift[25:22] + 4'd3;
                if (shift[29:26] >= 4'd5) shift[29:26] = shift[29:26] + 4'd3;
                shift = shift << 1;
            end

            bin_to_bcd4 = shift[29:14];
        end
    endfunction

    function automatic logic signed [11:0] desc_x(input logic [31:0] desc);
        desc_x = $signed(desc[27:16]);
    endfunction

    function automatic logic signed [11:0] desc_y(input logic [31:0] desc);
        desc_y = $signed(desc[15:4]);
    endfunction

    assign commit_pulse = commit_sync[2] ^ commit_sync[1];
    assign effect_pulse = effect_sync[2] ^ effect_sync[1];
    assign score_bcd = bin_to_bcd4(score_value);
    assign effect_event_x = $signed(effect_event_pio[25:14]);
    assign effect_event_y = $signed(effect_event_pio[13:2]);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            commit_sync <= 3'b000;
            effect_sync <= 3'b000;
        end else begin
            commit_sync <= {commit_sync[1:0], game_ctrl_pio[31]};
            effect_sync <= {effect_sync[1:0], effect_event_pio[31]};
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            overlay_enable <= 1'b0;
            game_state <= 2'd0;
            bomb_hits <= 2'd0;
            score_value <= 14'd0;
            time_tens <= 4'd6;
            time_ones <= 4'd0;

            for (int i = 0; i < MAX_FRUITS; i = i + 1) begin
                fruit_active[i] <= 1'b0;
                fruit_type[i] <= 3'd0;
                fruit_x[i] <= 12'sd0;
                fruit_y[i] <= 12'sd0;
            end
        end else if (commit_pulse) begin
            overlay_enable <= game_ctrl_pio[30];
            game_state <= game_ctrl_pio[29:28];
            bomb_hits <= game_ctrl_pio[27:26];
            score_value <= game_ctrl_pio[25:12];
            time_tens <= game_ctrl_pio[11:8];
            time_ones <= game_ctrl_pio[7:4];

            fruit_active[0] <= fruit0_desc_pio[31];
            fruit_type[0] <= fruit0_desc_pio[30:28];
            fruit_x[0] <= desc_x(fruit0_desc_pio);
            fruit_y[0] <= desc_y(fruit0_desc_pio);

            fruit_active[1] <= fruit1_desc_pio[31];
            fruit_type[1] <= fruit1_desc_pio[30:28];
            fruit_x[1] <= desc_x(fruit1_desc_pio);
            fruit_y[1] <= desc_y(fruit1_desc_pio);

            fruit_active[2] <= fruit2_desc_pio[31];
            fruit_type[2] <= fruit2_desc_pio[30:28];
            fruit_x[2] <= desc_x(fruit2_desc_pio);
            fruit_y[2] <= desc_y(fruit2_desc_pio);

            fruit_active[3] <= fruit3_desc_pio[31];
            fruit_type[3] <= fruit3_desc_pio[30:28];
            fruit_x[3] <= desc_x(fruit3_desc_pio);
            fruit_y[3] <= desc_y(fruit3_desc_pio);
        end
    end

    always_comb begin
        effect_start = '0;

        if (effect_pulse) begin
            effect_start[effect_event_pio[30:29]] = 1'b1;
        end
    end

    genvar fruit_i;
    generate
        for (fruit_i = 0; fruit_i < MAX_FRUITS; fruit_i = fruit_i + 1) begin : overlay_slots
            fruit_renderer fruit_renderer_inst (
                .clk          (clk),
                .reset        (reset),
                .fruit_active (overlay_enable && fruit_active[fruit_i]),
                .fruit_type   (fruit_type[fruit_i]),
                .fruit_x      (fruit_x[fruit_i]),
                .fruit_y      (fruit_y[fruit_i]),
                .DrawX        (draw_x),
                .DrawY        (draw_y),
                .fruit_hit    (fruit_hit[fruit_i]),
                .fruit_r      (fruit_r[fruit_i]),
                .fruit_g      (fruit_g[fruit_i]),
                .fruit_b      (fruit_b[fruit_i])
            );

            slice_effect_state slice_effect_state_inst (
                .clk            (clk),
                .reset          (reset),
                .clear          (!overlay_enable),
                .frame_tick     ((draw_x == 10'd0) && (draw_y == 10'd0)),
                .start_trigger  (effect_start[fruit_i]),
                .start_type     (effect_event_pio[28:26]),
                .start_x        (effect_event_x),
                .start_y        (effect_event_y),
                .effect_active  (effect_active[fruit_i]),
                .effect_type    (effect_type[fruit_i]),
                .effect_x       (effect_x[fruit_i]),
                .effect_y       (effect_y[fruit_i]),
                .effect_age     (effect_age[fruit_i])
            );

            slice_effect_renderer slice_effect_renderer_inst (
                .clk           (clk),
                .reset         (reset),
                .effect_active (effect_active[fruit_i]),
                .effect_type   (effect_type[fruit_i]),
                .effect_x      (effect_x[fruit_i]),
                .effect_y      (effect_y[fruit_i]),
                .effect_age    (effect_age[fruit_i]),
                .DrawX         (draw_x),
                .DrawY         (draw_y),
                .effect_hit    (effect_hit[fruit_i]),
                .effect_r      (effect_r[fruit_i]),
                .effect_g      (effect_g[fruit_i]),
                .effect_b      (effect_b[fruit_i])
            );
        end
    endgenerate

    ui_renderer ui_renderer_inst (
        .DrawX           (draw_x),
        .DrawY           (draw_y),
        .game_state      (game_state),
        .bomb_hits       (bomb_hits),
        .score_thousands (score_bcd[15:12]),
        .score_hundreds  (score_bcd[11:8]),
        .score_tens      (score_bcd[7:4]),
        .score_ones      (score_bcd[3:0]),
        .time_tens       (time_tens),
        .time_ones       (time_ones),
        .ui_hit          (ui_hit),
        .ui_r            (ui_r),
        .ui_g            (ui_g),
        .ui_b            (ui_b)
    );

    always_comb begin
        next_r = bg_r;
        next_g = bg_g;
        next_b = bg_b;

        if (blank_n && overlay_enable) begin
            for (int i = 0; i < MAX_FRUITS; i = i + 1) begin
                if (fruit_hit[i]) begin
                    next_r = fruit_r[i][9:2];
                    next_g = fruit_g[i][9:2];
                    next_b = fruit_b[i][9:2];
                end
            end

            for (int i = 0; i < MAX_FRUITS; i = i + 1) begin
                if (effect_hit[i]) begin
                    next_r = effect_r[i][9:2];
                    next_g = effect_g[i][9:2];
                    next_b = effect_b[i][9:2];
                end
            end

            if (ui_hit) begin
                next_r = ui_r[9:2];
                next_g = ui_g[9:2];
                next_b = ui_b[9:2];
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            out_r <= 8'h00;
            out_g <= 8'h00;
            out_b <= 8'h00;
        end else begin
            out_r <= next_r;
            out_g <= next_g;
            out_b <= next_b;
        end
    end

endmodule

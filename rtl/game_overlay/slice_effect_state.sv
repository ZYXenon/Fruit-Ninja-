module slice_effect_state (
    input  logic               clk,
    input  logic               reset,
    input  logic               clear,
    input  logic               frame_tick,

    input  logic               start_trigger,
    input  logic [2:0]         start_type,
    input  logic signed [11:0] start_x,
    input  logic signed [11:0] start_y,

    output logic               effect_active,
    output logic [2:0]         effect_type,
    output logic signed [11:0] effect_x,
    output logic signed [11:0] effect_y,
    output logic [4:0]         effect_age
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            effect_active <= 1'b0;
            effect_type <= 3'd0;
            effect_x <= 12'sd0;
            effect_y <= 12'sd0;
            effect_age <= 5'd0;
        end else if (clear) begin
            effect_active <= 1'b0;
            effect_type <= 3'd0;
            effect_x <= 12'sd0;
            effect_y <= 12'sd0;
            effect_age <= 5'd0;
        end else if (start_trigger) begin
            effect_active <= 1'b1;
            effect_type <= start_type;
            effect_x <= start_x;
            effect_y <= start_y;
            effect_age <= 5'd0;
        end else if (frame_tick && effect_active) begin
            if (effect_age == 5'd28) begin
                effect_active <= 1'b0;
            end else begin
                effect_age <= effect_age + 5'd1;
            end
        end
    end

endmodule

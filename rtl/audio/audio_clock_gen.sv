module audio_clock_gen (
    input  logic clk_50,
    input  logic reset,
    output logic audio_xck,
    output logic locked
);

`ifdef SIMULATION
    logic [1:0] div_count;

    always_ff @(posedge clk_50 or posedge reset) begin
        if (reset) begin
            div_count <= 2'd0;
            audio_xck <= 1'b0;
            locked <= 1'b0;
        end else begin
            div_count <= div_count + 2'd1;
            if (div_count == 2'd1) begin
                audio_xck <= ~audio_xck;
            end
            locked <= 1'b1;
        end
    end
`else
    wire [5:0] pll_clk;
    wire       pll_locked;

    altpll #(
        .intended_device_family ("Cyclone IV E"),
        .operation_mode         ("NORMAL"),
        .compensate_clock       ("CLK0"),
        .inclk0_input_frequency (20000),
        .clk0_multiply_by       (6),
        .clk0_divide_by         (25),
        .clk0_duty_cycle        (50),
        .clk0_phase_shift       ("0"),
        .lpm_type               ("altpll")
    ) audio_pll (
        .areset (reset),
        .inclk  ({1'b0, clk_50}),
        .clk    (pll_clk),
        .locked (pll_locked)
    );

    assign audio_xck = pll_clk[0];
    assign locked = pll_locked;
`endif

endmodule

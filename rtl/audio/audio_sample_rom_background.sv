`include "rtl/audio/audio_background_params.svh"

module audio_sample_rom_background (
    input  logic                                    clk,
    input  logic [`AUDIO_BACKGROUND_ADDR_WIDTH-1:0] addr,
    output logic [7:0]                              sample_byte
);

`ifdef SIMULATION
    logic [7:0] rom [0:`AUDIO_BACKGROUND_BYTE_COUNT-1];

    initial begin
        $readmemh("audio_background_adpcm_4k.mem", rom);
    end

    always_ff @(posedge clk) begin
        sample_byte <= rom[addr];
    end
`else
    logic [7:0] rom_q;

    altsyncram #(
        .address_aclr_a         ("NONE"),
        .clock_enable_input_a   ("BYPASS"),
        .clock_enable_output_a  ("BYPASS"),
        .intended_device_family ("Cyclone IV E"),
        .init_file              ("audio_background_adpcm_4k.mif"),
        .lpm_hint               ("ENABLE_RUNTIME_MOD=NO"),
        .lpm_type               ("altsyncram"),
        .numwords_a             (`AUDIO_BACKGROUND_BYTE_COUNT),
        .operation_mode         ("ROM"),
        .outdata_aclr_a         ("NONE"),
        .outdata_reg_a          ("CLOCK0"),
        .widthad_a              (`AUDIO_BACKGROUND_ADDR_WIDTH),
        .width_a                (8),
        .width_byteena_a        (1)
    ) rom_inst (
        .address_a (addr),
        .clock0    (clk),
        .q_a       (rom_q),
        .aclr0     (1'b0),
        .aclr1     (1'b0),
        .address_b (1'b0),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a (1'b1),
        .byteena_b (1'b1),
        .clock1    (1'b1),
        .clocken0  (1'b1),
        .clocken1  (1'b1),
        .clocken2  (1'b1),
        .clocken3  (1'b1),
        .data_a    (8'd0),
        .data_b    (1'b0),
        .eccstatus (),
        .q_b       (),
        .rden_a    (1'b1),
        .rden_b    (1'b1),
        .wren_a    (1'b0),
        .wren_b    (1'b0)
    );

    always_ff @(posedge clk) begin
        sample_byte <= rom_q;
    end
`endif

endmodule

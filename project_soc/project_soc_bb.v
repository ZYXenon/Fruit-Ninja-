
module project_soc (
	cam_ctrl_export,
	clk_clk,
	i2c_0_i2c_serial_sda_in,
	i2c_0_i2c_serial_scl_in,
	i2c_0_i2c_serial_sda_oe,
	i2c_0_i2c_serial_scl_oe,
	reset_reset_n,
	sdram_clk_clk,
	sdram_wire_addr,
	sdram_wire_ba,
	sdram_wire_cas_n,
	sdram_wire_cke,
	sdram_wire_cs_n,
	sdram_wire_dq,
	sdram_wire_dqm,
	sdram_wire_ras_n,
	sdram_wire_we_n,
	keys_export,
	frame_counter_pio_external_connection_export,
	tracker_status_pio_external_connection_export,
	game_ctrl_pio_external_connection_export,
	fruit0_desc_pio_external_connection_export,
	fruit1_desc_pio_external_connection_export,
	fruit2_desc_pio_external_connection_export,
	fruit3_desc_pio_external_connection_export,
	effect_event_pio_external_connection_export);	

	output	[1:0]	cam_ctrl_export;
	input		clk_clk;
	input		i2c_0_i2c_serial_sda_in;
	input		i2c_0_i2c_serial_scl_in;
	output		i2c_0_i2c_serial_sda_oe;
	output		i2c_0_i2c_serial_scl_oe;
	input		reset_reset_n;
	output		sdram_clk_clk;
	output	[12:0]	sdram_wire_addr;
	output	[1:0]	sdram_wire_ba;
	output		sdram_wire_cas_n;
	output		sdram_wire_cke;
	output		sdram_wire_cs_n;
	inout	[31:0]	sdram_wire_dq;
	output	[3:0]	sdram_wire_dqm;
	output		sdram_wire_ras_n;
	output		sdram_wire_we_n;
	input	[3:0]	keys_export;
	input	[31:0]	frame_counter_pio_external_connection_export;
	input	[31:0]	tracker_status_pio_external_connection_export;
	output	[31:0]	game_ctrl_pio_external_connection_export;
	output	[31:0]	fruit0_desc_pio_external_connection_export;
	output	[31:0]	fruit1_desc_pio_external_connection_export;
	output	[31:0]	fruit2_desc_pio_external_connection_export;
	output	[31:0]	fruit3_desc_pio_external_connection_export;
	output	[31:0]	effect_event_pio_external_connection_export;
endmodule

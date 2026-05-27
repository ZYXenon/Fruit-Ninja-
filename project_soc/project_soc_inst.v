	project_soc u0 (
		.cam_ctrl_export                               (<connected-to-cam_ctrl_export>),                               //                               cam_ctrl.export
		.clk_clk                                       (<connected-to-clk_clk>),                                       //                                    clk.clk
		.i2c_0_i2c_serial_sda_in                       (<connected-to-i2c_0_i2c_serial_sda_in>),                       //                       i2c_0_i2c_serial.sda_in
		.i2c_0_i2c_serial_scl_in                       (<connected-to-i2c_0_i2c_serial_scl_in>),                       //                                       .scl_in
		.i2c_0_i2c_serial_sda_oe                       (<connected-to-i2c_0_i2c_serial_sda_oe>),                       //                                       .sda_oe
		.i2c_0_i2c_serial_scl_oe                       (<connected-to-i2c_0_i2c_serial_scl_oe>),                       //                                       .scl_oe
		.reset_reset_n                                 (<connected-to-reset_reset_n>),                                 //                                  reset.reset_n
		.sdram_clk_clk                                 (<connected-to-sdram_clk_clk>),                                 //                              sdram_clk.clk
		.sdram_wire_addr                               (<connected-to-sdram_wire_addr>),                               //                             sdram_wire.addr
		.sdram_wire_ba                                 (<connected-to-sdram_wire_ba>),                                 //                                       .ba
		.sdram_wire_cas_n                              (<connected-to-sdram_wire_cas_n>),                              //                                       .cas_n
		.sdram_wire_cke                                (<connected-to-sdram_wire_cke>),                                //                                       .cke
		.sdram_wire_cs_n                               (<connected-to-sdram_wire_cs_n>),                               //                                       .cs_n
		.sdram_wire_dq                                 (<connected-to-sdram_wire_dq>),                                 //                                       .dq
		.sdram_wire_dqm                                (<connected-to-sdram_wire_dqm>),                                //                                       .dqm
		.sdram_wire_ras_n                              (<connected-to-sdram_wire_ras_n>),                              //                                       .ras_n
		.sdram_wire_we_n                               (<connected-to-sdram_wire_we_n>),                               //                                       .we_n
		.keys_export                                   (<connected-to-keys_export>),                                   //                                   keys.export
		.frame_counter_pio_external_connection_export  (<connected-to-frame_counter_pio_external_connection_export>),  //  frame_counter_pio_external_connection.export
		.tracker_status_pio_external_connection_export (<connected-to-tracker_status_pio_external_connection_export>), // tracker_status_pio_external_connection.export
		.game_ctrl_pio_external_connection_export      (<connected-to-game_ctrl_pio_external_connection_export>),      //      game_ctrl_pio_external_connection.export
		.fruit0_desc_pio_external_connection_export    (<connected-to-fruit0_desc_pio_external_connection_export>),    //    fruit0_desc_pio_external_connection.export
		.fruit1_desc_pio_external_connection_export    (<connected-to-fruit1_desc_pio_external_connection_export>),    //    fruit1_desc_pio_external_connection.export
		.fruit2_desc_pio_external_connection_export    (<connected-to-fruit2_desc_pio_external_connection_export>),    //    fruit2_desc_pio_external_connection.export
		.fruit3_desc_pio_external_connection_export    (<connected-to-fruit3_desc_pio_external_connection_export>),    //    fruit3_desc_pio_external_connection.export
		.effect_event_pio_external_connection_export   (<connected-to-effect_event_pio_external_connection_export>)    //   effect_event_pio_external_connection.export
	);


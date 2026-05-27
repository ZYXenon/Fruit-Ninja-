	component project_soc is
		port (
			cam_ctrl_export                               : out   std_logic_vector(1 downto 0);                     -- export
			clk_clk                                       : in    std_logic                     := 'X';             -- clk
			i2c_0_i2c_serial_sda_in                       : in    std_logic                     := 'X';             -- sda_in
			i2c_0_i2c_serial_scl_in                       : in    std_logic                     := 'X';             -- scl_in
			i2c_0_i2c_serial_sda_oe                       : out   std_logic;                                        -- sda_oe
			i2c_0_i2c_serial_scl_oe                       : out   std_logic;                                        -- scl_oe
			reset_reset_n                                 : in    std_logic                     := 'X';             -- reset_n
			sdram_clk_clk                                 : out   std_logic;                                        -- clk
			sdram_wire_addr                               : out   std_logic_vector(12 downto 0);                    -- addr
			sdram_wire_ba                                 : out   std_logic_vector(1 downto 0);                     -- ba
			sdram_wire_cas_n                              : out   std_logic;                                        -- cas_n
			sdram_wire_cke                                : out   std_logic;                                        -- cke
			sdram_wire_cs_n                               : out   std_logic;                                        -- cs_n
			sdram_wire_dq                                 : inout std_logic_vector(31 downto 0) := (others => 'X'); -- dq
			sdram_wire_dqm                                : out   std_logic_vector(3 downto 0);                     -- dqm
			sdram_wire_ras_n                              : out   std_logic;                                        -- ras_n
			sdram_wire_we_n                               : out   std_logic;                                        -- we_n
			keys_export                                   : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- export
			frame_counter_pio_external_connection_export  : in    std_logic_vector(31 downto 0) := (others => 'X'); -- export
			tracker_status_pio_external_connection_export : in    std_logic_vector(31 downto 0) := (others => 'X'); -- export
			game_ctrl_pio_external_connection_export      : out   std_logic_vector(31 downto 0);                    -- export
			fruit0_desc_pio_external_connection_export    : out   std_logic_vector(31 downto 0);                    -- export
			fruit1_desc_pio_external_connection_export    : out   std_logic_vector(31 downto 0);                    -- export
			fruit2_desc_pio_external_connection_export    : out   std_logic_vector(31 downto 0);                    -- export
			fruit3_desc_pio_external_connection_export    : out   std_logic_vector(31 downto 0);                    -- export
			effect_event_pio_external_connection_export   : out   std_logic_vector(31 downto 0)                     -- export
		);
	end component project_soc;

	u0 : component project_soc
		port map (
			cam_ctrl_export                               => CONNECTED_TO_cam_ctrl_export,                               --                               cam_ctrl.export
			clk_clk                                       => CONNECTED_TO_clk_clk,                                       --                                    clk.clk
			i2c_0_i2c_serial_sda_in                       => CONNECTED_TO_i2c_0_i2c_serial_sda_in,                       --                       i2c_0_i2c_serial.sda_in
			i2c_0_i2c_serial_scl_in                       => CONNECTED_TO_i2c_0_i2c_serial_scl_in,                       --                                       .scl_in
			i2c_0_i2c_serial_sda_oe                       => CONNECTED_TO_i2c_0_i2c_serial_sda_oe,                       --                                       .sda_oe
			i2c_0_i2c_serial_scl_oe                       => CONNECTED_TO_i2c_0_i2c_serial_scl_oe,                       --                                       .scl_oe
			reset_reset_n                                 => CONNECTED_TO_reset_reset_n,                                 --                                  reset.reset_n
			sdram_clk_clk                                 => CONNECTED_TO_sdram_clk_clk,                                 --                              sdram_clk.clk
			sdram_wire_addr                               => CONNECTED_TO_sdram_wire_addr,                               --                             sdram_wire.addr
			sdram_wire_ba                                 => CONNECTED_TO_sdram_wire_ba,                                 --                                       .ba
			sdram_wire_cas_n                              => CONNECTED_TO_sdram_wire_cas_n,                              --                                       .cas_n
			sdram_wire_cke                                => CONNECTED_TO_sdram_wire_cke,                                --                                       .cke
			sdram_wire_cs_n                               => CONNECTED_TO_sdram_wire_cs_n,                               --                                       .cs_n
			sdram_wire_dq                                 => CONNECTED_TO_sdram_wire_dq,                                 --                                       .dq
			sdram_wire_dqm                                => CONNECTED_TO_sdram_wire_dqm,                                --                                       .dqm
			sdram_wire_ras_n                              => CONNECTED_TO_sdram_wire_ras_n,                              --                                       .ras_n
			sdram_wire_we_n                               => CONNECTED_TO_sdram_wire_we_n,                               --                                       .we_n
			keys_export                                   => CONNECTED_TO_keys_export,                                   --                                   keys.export
			frame_counter_pio_external_connection_export  => CONNECTED_TO_frame_counter_pio_external_connection_export,  --  frame_counter_pio_external_connection.export
			tracker_status_pio_external_connection_export => CONNECTED_TO_tracker_status_pio_external_connection_export, -- tracker_status_pio_external_connection.export
			game_ctrl_pio_external_connection_export      => CONNECTED_TO_game_ctrl_pio_external_connection_export,      --      game_ctrl_pio_external_connection.export
			fruit0_desc_pio_external_connection_export    => CONNECTED_TO_fruit0_desc_pio_external_connection_export,    --    fruit0_desc_pio_external_connection.export
			fruit1_desc_pio_external_connection_export    => CONNECTED_TO_fruit1_desc_pio_external_connection_export,    --    fruit1_desc_pio_external_connection.export
			fruit2_desc_pio_external_connection_export    => CONNECTED_TO_fruit2_desc_pio_external_connection_export,    --    fruit2_desc_pio_external_connection.export
			fruit3_desc_pio_external_connection_export    => CONNECTED_TO_fruit3_desc_pio_external_connection_export,    --    fruit3_desc_pio_external_connection.export
			effect_event_pio_external_connection_export   => CONNECTED_TO_effect_event_pio_external_connection_export    --   effect_event_pio_external_connection.export
		);


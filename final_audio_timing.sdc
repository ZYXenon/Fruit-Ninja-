create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
create_clock -name CAM_PCLK -period 41.667 [get_ports {CAM_PCLK}]
create_clock -name AUD_BCLK -period 325.521 [get_ports {AUD_BCLK}]

create_generated_clock -name VGA_CLK_INT -source [get_ports {CLOCK_50}] -divide_by 2 [get_registers {vga_clk}]

derive_pll_clocks
derive_clock_uncertainty

set_clock_groups -asynchronous \
    -group [get_clocks {CLOCK_50 VGA_CLK_INT}] \
    -group [get_clocks {CAM_PCLK}] \
    -group [get_clocks {AUD_BCLK}]

# WM8731 master mode changes DACLRC after BCLK falling edge and samples DACDAT on BCLK rising edge.
# The 3.072 MHz BCLK half-period is wide; these loose delays mainly keep the DACDAT output path timed.
set_output_delay -clock [get_clocks {AUD_BCLK}] -max 100.000 [get_ports {AUD_DACDAT}]
set_output_delay -clock [get_clocks {AUD_BCLK}] -min -20.000 [get_ports {AUD_DACDAT}]

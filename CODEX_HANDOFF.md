# Codex Handoff: OV2640 to VGA Bring-Up

## Current Goal

Implement live OV2640 camera display on DE2-115 VGA output as the first bring-up stage for the AR Fruit Ninja project.

Current chosen design:

- Camera module: OV2640 module through GPIO.
- Camera configuration: RGB565, QVGA 320x240.
- VGA output: 640x480, 2x nearest-neighbor upscale from QVGA.
- Framebuffer: DE2-115 onboard SRAM, 16-bit RGB565 words.
- Buffering: triple buffering, 3 frames in SRAM.
- Nios II role: configure OV2640 through Avalon I2C/SCCB and control `PWDN/RESET_N`.
- HDL role: realtime camera capture, SRAM framebuffer, VGA output.

Important user instruction: do not inspect `.git` contents. Do not directly edit Quartus-generated project configuration such as `.qsf` when the task should be performed through Quartus GUI; provide import files/instructions instead.

## Files Added Or Modified By Codex

### Top-Level HDL

- `project/final_top.sv`
  - Top-level entity is `final_top`.
  - Instantiates `project_soc`, `VGA_controller`, camera capture, async FIFO, SRAM writer/reader/arbiter, RGB LUT, and fallback VGA test pattern.
  - Connects SoC I2C exported pins to OV2640 SCCB pins as open-drain:
    - `CAM_SIOD = i2c_sda_oe ? 1'b0 : 1'bz`
    - `CAM_SIOC = i2c_scl_oe ? 1'b0 : 1'bz`
  - Maps `cam_ctrl_export[0]` to `CAM_PWDN`.
  - Maps `cam_ctrl_export[1]` to `CAM_RESET_N`.
  - Currently generates VGA clock by dividing `CLOCK_50` by 2 in fabric. This works for early bring-up, but a PLL-generated 25 MHz VGA clock is preferred later.
  - Note: original `final.sv` module name was changed because `final` is a SystemVerilog reserved keyword. The file was renamed by the user to `final_top.sv`.

### HDL Modules In `project/rtl/`

- `async_fifo.sv`
  - Async FIFO for crossing camera PCLK domain into VGA/SRAM domain.
  - Data width is 18 bits: `{sof, reserved, rgb565[15:0]}`.

- `ov2640_capture.sv`
  - Samples `CAM_D[7:0]` on `CAM_PCLK`.
  - Uses `CAM_HREF` to collect two bytes per RGB565 pixel.
  - Marks first pixel after `CAM_VSYNC` with SOF.
  - Does not route `CAM_D[7:0]` through Platform Designer PIO.

- `sram_arbiter.sv`
  - Simple 16-bit SRAM controller/arbitration.
  - Gives read requests priority over writes.
  - Drives SRAM control pins: `SRAM_ADDR`, `SRAM_DQ`, `SRAM_CE_N`, `SRAM_OE_N`, `SRAM_WE_N`, `SRAM_UB_N`, `SRAM_LB_N`.

- `sram_frame_writer.sv`
  - Consumes camera FIFO pixels and writes full QVGA frames into SRAM.
  - Triple-buffer layout:
    - frame 0 base word address: `0`
    - frame 1 base word address: `76800`
    - frame 2 base word address: `153600`
  - Each frame is `320 * 240 = 76800` 16-bit words.

- `vga_framebuffer_reader.sv`
  - Reads SRAM frame into two 320-pixel line buffers.
  - Uses `DrawX >> 1`, `DrawY >> 1` for 2x upscale to 640x480.
  - Swaps to pending completed frame at new VGA frame boundary.

- `rgb_lut.sv`
  - Expands RGB565 to RGB888.
  - Red/blue use 5-bit to 8-bit LUT.
  - Green uses 6-bit to 8-bit LUT.

- `vga_test_pattern.sv`
  - Fallback color-bar pattern when no valid camera framebuffer pixel is available.
  - Useful for VGA bring-up independent of camera.

### Nios Software

- `project/software/ninja/main.c`
  - Minimal bring-up app.
  - Calls:
    - `ov2640_basic_init()`
    - `ov2640_basic_set_rgb565_mode()`
    - `ov2640_basic_set_image_resolution(OV2640_IMAGE_RESOLUTION_QVGA)`
  - Prints status through JTAG UART.

- `project/software/ninja/driver_ov2640_interface_template.c`
  - Completed LibDriver platform interface.
  - Uses Avalon I2C device `/dev/i2c_0`.
  - Converts LibDriver 8-bit OV2640 address `0x60` to Avalon 7-bit target `0x30`.
  - Sets I2C speed to 100 kHz through `ALT_AVALON_I2C_MASTER_CONFIG_t`.
  - Controls `cam_ctrl_pio`:
    - bit 0: `PWDN`, high = power down, low = power on.
    - bit 1: `RESET_N`, low = reset, high = run.
  - Implements delay using `alt_busy_sleep`.
  - Implements debug output using `vprintf`.
  - SCCB read currently tries combined `alt_avalon_i2c_master_tx_rx`; if that fails, tries separate write-register-address then read.
  - Prints detailed I2C status on SCCB failure.

- `project/software/ninja/Makefile`
  - `C_SRCS` set to:
    - `main.c`
    - `driver_ov2640.c`
    - `driver_ov2640_basic.c`
    - `driver_ov2640_interface_template.c`
  - `APP_INCLUDE_DIRS := .`

### Assignment Import Helpers

- `project/pin_assignment_import.csv`
  - CSV pin assignment table for `final_top` ports.
  - Includes `CLOCK_50`, `KEY[3:0]`, `CAM_*`, `VGA_*`, `DRAM_*`, `SRAM_*`.
  - Includes weak pull-up column with pull-ups enabled on `CAM_SIOC` and `CAM_SIOD`.

- `project/cam_i2c_pullups_import.qsf`
  - Small Quartus import snippet:
    - `set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to CAM_SIOC`
    - `set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to CAM_SIOD`

## Platform Designer / BSP State

`project_soc` has been updated by the user in Platform Designer:

- Added `cam_ctrl_pio`
  - Width: 2 bits.
  - Direction: output.
  - Export name: `cam_ctrl`.
  - Generated top-level port: `cam_ctrl_export[1:0]`.
  - Base address in BSP: `CAM_CTRL_PIO_BASE = 0x20`.

- Added `jtag_uart_0`
  - Base address in BSP: `JTAG_UART_0_BASE = 0x88`.
  - IRQ 5.

- Existing Avalon I2C:
  - Device name: `/dev/i2c_0`.
  - Base address: `I2C_0_BASE = 0x40`.

BSP is now updated:

- `ALT_STDIN`, `ALT_STDOUT`, `ALT_STDERR` all point to `/dev/jtag_uart_0`.
- `CAM_CTRL_PIO_BASE`, `JTAG_UART_0_BASE`, and `__ALTERA_AVALON_JTAG_UART` are present in `system.h`.

## Quartus GUI Actions Required/Already Discussed

The user should keep using Quartus GUI for project configuration.

Needed/expected:

- Add HDL files to Quartus project:
  - `final_top.sv`
  - `VGA_controller.sv`
  - all `project/rtl/*.sv`
- Set top-level entity to `final_top`.
- Import or manually apply pin assignments from `project/pin_assignment_import.csv`.
- Import or manually apply weak pull-up assignments for `CAM_SIOC` and `CAM_SIOD`.
- Recompile Quartus and download the new `.sof` after pin/pull-up changes.
- Regenerate BSP after Platform Designer changes.
- Rebuild `ninja_bsp` and `ninja`.

## Current Runtime Status

Nios program runs and JTAG UART output works.

Observed console output before pull-up fix:

```text
OV2640 VGA bring-up starting
sccb read failed: dev=0x60 target7=0x30 reg=0xFF status=TIMEOUT(-2)
ov2640: sensor read failed.
ov2640: init failed.
OV2640 init failed
```

Interpretation:

- Nios app is running.
- JTAG UART works.
- LibDriver starts OV2640 init.
- Failure is at first SCCB/I2C register read.
- `TIMEOUT` strongly suggests SCCB lines are not returning high, or one line is stuck/incorrectly connected.

Next debugging steps:

1. Ensure `CAM_SIOC` and `CAM_SIOD` have pull-ups.
   - Import `project/cam_i2c_pullups_import.qsf`, or enable Weak Pull-Up Resistor manually in Assignment Editor.
   - Recompile Quartus and download new `.sof`.
2. Re-run Nios app.
3. If status changes to `NACK`, check OV2640 address, power, reset, wiring.
4. If status remains `TIMEOUT`, check:
   - `CAM_SIOC` and `CAM_SIOD` not swapped.
   - module has stable 3.3 V and GND.
   - `CAM_PWDN` is low during run.
   - `CAM_RESET_N` is high during run.
   - external 4.7k pull-ups to 3.3 V may be needed if internal weak pull-ups are insufficient.
5. Use SignalTap or oscilloscope/logic analyzer on `CAM_SIOC`, `CAM_SIOD`, `CAM_PWDN`, `CAM_RESET_N`.

## Important Design Notes For Next Codex

- Do not route `CAM_D[7:0]` through PIO. Pixel stream must stay in HDL.
- PIO only controls slow signals: `PWDN` and `RESET_N`.
- The current HDL video pipeline is first-pass bring-up code and has not been fully Quartus-verified by Codex because local PATH lacked Quartus/Nios command-line tools.
- The fabric-divided VGA clock in `final_top.sv` should eventually be replaced with a PLL-generated 25 MHz clock.
- If adding a 25 MHz clock:
  - Prefer a separate VGA PLL at top level, or export a new PLL output from `project_soc`.
  - Feed `VGA_controller.VGA_CLK`, framebuffer reader, SRAM video-side logic, and `VGA_CLK` output from that PLL output.
- OV2640 LibDriver default mirror/flip settings are currently whatever `driver_ov2640_basic.h` defines; adjust later if image orientation is wrong.
- RGB565 byte order may need swapping after camera link works. Current capture assumes first byte is high RGB565 byte and second byte is low RGB565 byte.
- The file `project/final.qsf` may still have project name `final`, which is okay. The HDL top-level entity must be `final_top`.

# SignalTap noise debug checklist

This checklist is for the current issue where live VGA color is correct, but
there are flickering point artifacts and horizontal strip artifacts. Do not try
to capture a full 320x240 frame. Use short event windows instead.

## Baseline

- Keep `OV2640_BASIC_DEFAULT_COLOR_BAR_TEST` disabled.
- Keep `OV2640_BASIC_DEFAULT_PCLK` at `OV2640_PCLK_DIVIDE_2`.
- Keep `OV2640_BASIC_DEFAULT_PCLK_EDGE` at `OV2640_EDGE_FALLING`.
- Leave `KEY[3:1]` unpressed so `color_debug_mode` is 0.
- Do not hand-edit `.qsf`; add SignalTap nodes through the Quartus GUI.

## Capture A: camera/FIFO write side

- SignalTap clock: `CAM_PCLK`.
- Sample depth: 8K or 16K.
- Storage qualifier: `cam_fifo_wr_valid == 1`.
- Trigger first choice: `debug_cam_backpressure == 1`.
- If that never triggers, trigger on `cam_fifo_wr_valid == 1` and repeat a few captures.

Probe these first:

- `cam_fifo_wr_valid`
- `cam_fifo_wr_ready`
- `cam_fifo_wr_data[17:0]`
- `debug_cam_backpressure`
- `cam_overflow_pulse`
- `cam_drop_frame`
- `cam_fifo_wr_level[11:0]`

Add only if resources allow:

- `CAM_HREF`
- `CAM_VSYNC`
- `cam_accepted_pixel_count[15:0]`

After exporting CSV:

```powershell
conda run -n 448 python project\convert_signaltap_rgb.py project\noise_cam.csv --strict-valid -o F:\tmp\noise_cam.png
```

Useful interpretation:

- `valid while not ready` above 0 means camera pixels were presented while the
  FIFO was not accepting data.
- `cam_overflow_pulse` or growing `cam_overflow_count` means dropped camera
  pixels/frames are still possible.
- If exported pixels already contain random noise while overflow does not grow,
  suspect camera input timing, PCLK margin, cable, power, or GPIO signal quality.

## Capture B: VGA/SRAM display side

- SignalTap clock: `vga_clk`.
- Sample depth: 8K or 16K.
- Storage qualifier: `VGA_BLANK_N == 1`.
- Trigger first choice: `debug_vga_visible_miss == 1`.
- If that never triggers, trigger on `VGA_HS` or `VGA_BLANK_N` and inspect
  several visible lines.

Probe these first:

- `VGA_BLANK_N`
- `VGA_HS`
- `VGA_VS`
- `draw_x[9:0]`
- `draw_y[9:0]`
- `vga_pixel_valid`
- `vga_pixel[15:0]`
- `display_sram_pixel`
- `debug_vga_visible_miss`
- `fb_mem_rd_req`
- `fb_mem_rd_ready`
- `fb_mem_rd_valid`
- `fb_mem_rd_addr[19:0]`

Add only if resources allow:

- `mem_rd_req`
- `mem_rd_ready`
- `mem_rd_valid`
- `mem_wr_valid`
- `mem_wr_ready`
- `writer_completed_frame_count`
- `writer_dropped_frame_count`
- `writer_debug_pixel_count`

Useful interpretation:

- `debug_vga_visible_miss == 1` during visible display means the framebuffer
  reader did not have a valid line pixel and the top level is displaying the
  fallback test pattern for that pixel/line.
- If `fb_mem_rd_req` is high but `fb_mem_rd_ready` is often low, SRAM arbitration
  is starving the VGA reader.
- If `fb_mem_rd_valid` is delayed or missing after accepted reads, inspect SRAM
  read timing and the arbiter read transaction.
- If `vga_pixel_valid` remains high while artifacts remain visible, suspect
  external SRAM timing/signal quality or camera-side bit errors rather than
  line-buffer starvation.

## Capture C: VGA output back end

Use this after Capture A is clean and Capture B shows no repeated
`vga_pixel_valid` misses. This capture checks whether blue vertical bars are
already present in the internal RGB path or appear only at the final VGA output.

- SignalTap clock: `vga_clk`.
- Sample depth: 8K or 16K.
- Storage qualifier: `VGA_BLANK_N == 1`.
- Trigger first choice: `VGA_BLANK_N == 1`.
- Use the smallest probe set that compiles; this capture is meant to disturb
  placement less than Capture B.

Probe these first:

- `VGA_R[7:0]`
- `VGA_G[7:0]`
- `VGA_B[7:0]`
- `cam_r[7:0]`
- `cam_g[7:0]`
- `cam_b[7:0]`
- `vga_pixel[15:0]`
- `vga_pixel_debug[15:0]`
- `display_sram_pixel`
- `vga_pixel_valid`
- `VGA_BLANK_N`
- `draw_x[9:0]`
- `draw_y[9:0]`

Useful interpretation:

- If `vga_pixel_debug` and `cam_r/g/b` already show the blue columns, inspect
  RGB565 expansion and SRAM read data.
- If `cam_r/g/b` look normal but `VGA_R/G/B` show the blue columns, inspect
  final VGA output timing, pin assignments, and TimeQuest constraints.
- If Capture C removes the original noise or changes the symptom, treat that
  bitstream as a debug-only placement and verify again with SignalTap disabled.

## Quartus timing checks

Do these in the Quartus GUI; do not hand-edit `.qsf`.

- Run a normal full compile without the heavy Capture B SignalTap instance and
  record whether the screen shows flickering dots, horizontal strips, or blue
  vertical bars.
- Open TimeQuest Timing Analyzer from the GUI and create/check clock
  constraints for `CLOCK_50`, `CAM_PCLK`, and the generated `vga_clk`.
- Check SRAM output/input timing paths around `SRAM_ADDR`, `SRAM_DQ`,
  `SRAM_OE_N`, and `SRAM_WE_N`. Any unconstrained or failing SRAM path is a
  likely cause of placement-sensitive artifacts.
- If constraints must be added, add them through Quartus/TimeQuest GUI flows so
  Quartus owns the generated project metadata.

## Node Finder hints

Use SignalTap Node Finder with post-fitting nodes and wildcard searches:

- `*debug_cam_backpressure*`
- `*debug_vga_visible_miss*`
- `*cam_fifo_wr*`
- `*cam_overflow*`
- `*vga_pixel*`
- `*vga_pixel_debug*`
- `*cam_r*`
- `*cam_g*`
- `*cam_b*`
- `*fb_mem_rd*`
- `*writer_*count*`

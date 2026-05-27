# FPGA AR Fruit Ninja 项目总览与实现计划

> 本文档用于放在项目仓库根目录，帮助 Claude Code / 开发者快速理解项目目标、硬件平台、模块划分、实现路径、接口约定与调试计划。

---

## 1. 项目简介

本项目是在 **DE2-115 FPGA 开发板** 上实现一个基于摄像头交互的 **AR Fruit Ninja** 游戏。

系统使用 **OV2640 摄像头**采集实时画面，并将画面显示在 **VGA 屏幕**上。玩家手持一个特定颜色的道具，例如荧光绿、亮粉色或纯蓝色物体。FPGA 实时识别该颜色道具在摄像头画面中的位置，并在 VGA 输出中叠加显示为一把虚拟水果刀。屏幕上会生成水果图案，玩家挥动道具使虚拟刀划过水果，系统检测碰撞并更新分数。

项目目标不是软件模拟游戏，而是一个完整的实时硬件视频系统：

- 摄像头实时采集；
- SDRAM frame buffer；
- VGA 实时输出；
- 特定颜色道具检测；
- 游戏图形叠加；
- Nios II 负责游戏状态和物理逻辑；
- SystemVerilog 硬件模块负责像素级处理和显示。

---

## 2. 目标硬件与开发环境

### 2.1 硬件平台

- FPGA Board: Terasic DE2-115
- Camera: OV2640 camera kit
- Display: VGA monitor, 640×480 @ 60 Hz
- External Memory: DE2-115 onboard SDRAM
- Optional input:
  - KEY buttons for start/reset/debug
  - SW switches for threshold/debug mode
  - HEX displays for score/debug values

### 2.2 软件与工具

- HDL: SystemVerilog
- CPU: Nios II
- Software: C
- Platform tools:
  - Intel Quartus / Platform Designer, formerly Qsys
  - Nios II Software Build Tools / Eclipse or command-line build
  - ModelSim / Questa for simulation
  - SignalTap for hardware debugging

---

## 3. 推荐实现策略

为了保证 demo 成功率，项目采用 **硬件处理像素，软件处理游戏逻辑** 的分工。

### 3.1 硬件负责

- OV2640 SCCB/I2C 初始化；
- 摄像头像素采集与 RGB565 解码；
- 摄像头帧写入 SDRAM；
- VGA 从 SDRAM 读取背景画面；
- VGA timing generation；
- 特定颜色道具实时检测；
- 计算道具 bounding box 和中心点；
- sprite / blade / UI 图层叠加；
- Avalon-MM 寄存器接口；
- Nios 与显示模块之间的同步。

### 3.2 Nios II 软件负责

- 游戏状态机；
- 水果生成；
- 水果运动轨迹；
- 刀与水果碰撞检测；
- 分数、生命、倒计时；
- sprite descriptor table 更新；
- 颜色阈值参数配置；
- debug / calibration 模式控制。

---

## 4. 总体架构

```text
OV2640 Camera
   |
   | DVP interface: PCLK / VSYNC / HREF / D[7:0]
   v
Camera Capture + RGB565 Packer
   |
   +-----------------------> Color Prop Tracker
   |                              |
   |                              v
   |                      Tracker Registers
   |                              |
   v                              v
SDRAM Frame Buffer <-------- Nios II Game Logic
   |                              |
   v                              v
VGA Background Reader       Sprite / UI Registers
   |                              |
   +--------------+---------------+
                  v
        Layer Compositor
        Camera + Fruits + Blade + Effects + UI
                  |
                  v
           VGA Controller
                  |
                  v
             VGA Monitor
```

---

## 5. 分辨率与像素格式约定

### 5.1 摄像头输入

推荐配置 OV2640 输出：

```text
Resolution: 320×240 QVGA
Pixel format: RGB565
Frame rate: 约 30 fps
```

理由：

- 320×240 比 640×480 容易处理；
- SDRAM 带宽压力低；
- VGA 可用 2× 放大显示到 640×480；
- 颜色追踪计算量小；
- debug 更容易。

### 5.2 VGA 输出

```text
Resolution: 640×480
Refresh: 60 Hz
Pixel clock: 25.175 MHz, or 25 MHz if monitor accepts
Color format: RGB565 internally, converted to VGA RGB output
```

### 5.3 坐标映射

摄像头坐标：

```text
cam_x: 0..319
cam_y: 0..239
```

VGA 坐标：

```text
vga_x: 0..639
vga_y: 0..479
```

镜像显示时：

```verilog
cam_x = 319 - (vga_x >> 1);
cam_y = vga_y >> 1;
```

非镜像显示时：

```verilog
cam_x = vga_x >> 1;
cam_y = vga_y >> 1;
```

游戏建议使用 VGA 坐标系，即 640×480。

---

## 6. 时钟域设计

系统中存在多个时钟域，跨域必须明确处理。

| Clock | Source | Usage |
|---|---|---|
| `clk_50` | DE2-115 onboard clock | base clock |
| `cam_xclk` | PLL output, usually 24 MHz | OV2640 external clock |
| `cam_pclk` | OV2640 output | camera pixel capture |
| `vga_clk` | PLL output, 25.175 MHz or 25 MHz | VGA pixel timing |
| `sdram_clk` | PLL output, often 100 MHz | SDRAM controller / Avalon / Nios |

### 6.1 跨时钟域原则

不要直接跨域传递多 bit 数据。

推荐做法：

- Camera PCLK → SDRAM writer: asynchronous FIFO；
- Camera tracker result → Nios: frame_done toggle + synchronized result registers；
- Nios → VGA renderer: sprite descriptor 双缓冲；
- SDRAM → VGA: line buffer / FIFO；
- frame buffer swap: 只在 VGA vblank 生效。

---

## 7. Frame Buffer 设计

### 7.1 一帧大小

```text
320 × 240 × 2 bytes = 153,600 bytes/frame
```

推荐使用 triple buffer：

```text
buffer0: camera write candidate
buffer1: VGA read active
buffer2: spare / next buffer
```

三帧总容量：

```text
3 × 153,600 = 460,800 bytes
```

### 7.2 地址计算

```verilog
byte_addr = frame_base + ((y * 320) + x) * 2;
```

硬件优化：

```verilog
line_base = frame_base + y * 640;  // 320 pixels * 2 bytes
byte_addr = line_base + (x << 1);
```

### 7.3 防止 screen tearing

不要让 VGA 读取 camera 正在写入的 frame。

推荐 swap 流程：

```text
1. Camera writes write_buf.
2. VGA reads read_buf.
3. Camera frame_done sets write_buf_full.
4. At VGA vblank:
      if write_buf_full:
          swap read_buf and write_buf
          clear write_buf_full
```

---

## 8. 颜色道具追踪算法

本项目推荐使用 **Color Prop Tracking**，而不是普通 frame differencing。玩家手持一个特殊颜色道具，硬件在摄像头流中实时寻找该颜色。

### 8.1 RGB565 分量

```verilog
logic [4:0] r5;
logic [5:0] g6;
logic [4:0] b5;

assign r5 = pix_rgb565[15:11];
assign g6 = pix_rgb565[10:5];
assign b5 = pix_rgb565[4:0];
```

### 8.2 绿色道具检测示例

```verilog
is_prop =
    (g6 > G_MIN) &&
    (g6 > {r5, 1'b0} + MARGIN_GR) &&
    (g6 > {b5, 1'b0} + MARGIN_GB);
```

### 8.3 粉色道具检测示例

```verilog
is_prop =
    (r5 > R_MIN) &&
    (b5 > B_MIN) &&
    (g6 < G_MAX) &&
    ({1'b0, r5} + {1'b0, b5} > RB_MIN);
```

### 8.4 每帧 bounding box 统计

在 `cam_pclk` 域内：

```verilog
if (frame_start) begin
    count <= 0;
    min_x <= 319;
    max_x <= 0;
    min_y <= 239;
    max_y <= 0;
end

if (pix_valid && is_prop) begin
    count <= count + 1;
    if (pix_x < min_x) min_x <= pix_x;
    if (pix_x > max_x) max_x <= pix_x;
    if (pix_y < min_y) min_y <= pix_y;
    if (pix_y > max_y) max_y <= pix_y;
end
```

frame end 时：

```verilog
if (count > PROP_COUNT_MIN) begin
    prop_valid <= 1'b1;
    prop_cx <= (min_x + max_x) >> 1;
    prop_cy <= (min_y + max_y) >> 1;
end else begin
    prop_valid <= 1'b0;
end
```

转换到 VGA 坐标：

```verilog
blade_x = 2 * (319 - prop_cx);  // mirrored display
blade_y = 2 * prop_cy;
```

### 8.5 刀是否 active

Nios 读取当前和上一帧刀位置，计算速度：

```c
int dx = blade_x - prev_blade_x;
int dy = blade_y - prev_blade_y;
int speed2 = dx * dx + dy * dy;
blade_active = prop_valid && speed2 > SPEED_THRESHOLD;
```

只有 `blade_active` 时才允许切水果，避免刀停在水果上自动得分。

---

## 9. VGA 图层合成

最终 VGA 像素按优先级合成：

```text
Layer 0: live camera background
Layer 1: fruit sprites
Layer 2: sliced fruit halves / particles / slash trail
Layer 3: blade cursor
Layer 4: UI text, score, timer, lives
```

推荐组合逻辑：

```verilog
rgb_bg = camera_pixel;

rgb1 = fruit_hit  ? fruit_pixel  : rgb_bg;
rgb2 = effect_hit ? effect_pixel : rgb1;
rgb3 = blade_hit  ? blade_pixel  : rgb2;
rgb4 = ui_hit     ? ui_pixel     : rgb3;

vga_rgb = rgb4;
```

### 9.1 Sprite 透明色

Baseline 阶段使用 color key：

```verilog
transparent = (sprite_pixel == 16'hF81F);  // magenta transparent
```

如果 sprite pixel 是透明色，则显示下层背景。否则覆盖。

### 9.2 Sprite descriptor

每个 sprite 建议 16 bytes：

```c
typedef struct {
    uint32_t ctrl;     // enable, type, flags
    uint32_t xy;       // y[31:16], x[15:0]
    uint32_t anim;     // frame, priority, state
    uint32_t extra;    // radius, effect timer, etc.
} SpriteDesc;
```

硬件读取 descriptor 后在当前 VGA pixel 上判断是否命中 sprite。

---

## 10. Avalon-MM 寄存器地图建议

建议做一个 `game_mmio` Avalon-MM slave。所有软件/硬件交互都通过这个模块。

### 10.1 Tracker registers

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x000` | `TRACK_STATUS` | R | bit0 valid, bit1 new_frame |
| `0x004` | `TRACK_XY` | R | `{blade_y[15:0], blade_x[15:0]}` |
| `0x008` | `TRACK_PREV_XY` | R | previous blade position |
| `0x00C` | `TRACK_BBOX0` | R | `{min_y[15:0], min_x[15:0]}` |
| `0x010` | `TRACK_BBOX1` | R | `{max_y[15:0], max_x[15:0]}` |
| `0x014` | `TRACK_COUNT` | R | detected pixel count |
| `0x018` | `TRACK_FRAME_ID` | R | camera frame counter |

### 10.2 Color threshold registers

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x020` | `PROP_R_MIN` | R/W | red threshold |
| `0x024` | `PROP_G_MIN` | R/W | green threshold |
| `0x028` | `PROP_B_MIN` | R/W | blue threshold |
| `0x02C` | `PROP_MARGIN` | R/W | color dominance margin |
| `0x030` | `PROP_COUNT_MIN` | R/W | minimum detected pixels |

### 10.3 Game state registers

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x040` | `GAME_STATE` | R/W | start / playing / game over |
| `0x044` | `SCORE` | R/W | current score |
| `0x048` | `LIVES` | R/W | remaining lives |
| `0x04C` | `TIME_LEFT` | R/W | countdown timer |
| `0x050` | `DEBUG_MODE` | R/W | display debug overlays |

### 10.4 Sprite table

```text
Base offset: 0x100
Entry size:  16 bytes
Max sprites: 16 or 32
```

For sprite `i`:

| Offset | Field |
|---:|---|
| `0x100 + i*16 + 0x0` | `SPRITE_CTRL` |
| `0x100 + i*16 + 0x4` | `SPRITE_XY` |
| `0x100 + i*16 + 0x8` | `SPRITE_ANIM` |
| `0x100 + i*16 + 0xC` | `SPRITE_EXTRA` |

Commit register:

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x0F0` | `SPRITE_COMMIT` | W | Nios writes 1 to request sprite table update |
| `0x0F4` | `VBLANK_STATUS` | R | bit0 vblank, bit1 commit_done |

推荐实现 sprite descriptor 双缓冲：

```text
Nios writes inactive sprite table.
Nios writes SPRITE_COMMIT = 1.
VGA logic swaps active table only during vblank.
```

---

## 11. Nios II 游戏逻辑

### 11.1 游戏状态机

```c
typedef enum {
    GAME_START = 0,
    GAME_PLAYING = 1,
    GAME_OVER = 2
} GameState;
```

状态行为：

```text
GAME_START:
    显示标题界面。
    等待 KEY 或有效挥刀开始。

GAME_PLAYING:
    生成水果。
    更新水果位置。
    读取 blade 坐标。
    检测 blade 与 fruit 碰撞。
    更新分数、生命和倒计时。
    写入 sprite table。

GAME_OVER:
    显示最终分数。
    等待 reset / start。
```

### 11.2 水果结构体

```c
typedef struct {
    int active;
    int type;          // apple, banana, watermelon, bomb
    int sliced;
    int x, y;          // fixed point Q10.6
    int vx, vy;        // fixed point Q10.6
    int radius;
    int anim_frame;
    int lifetime;
} Fruit;
```

固定点约定：

```c
#define FP_SHIFT 6
#define TO_FP(x) ((x) << FP_SHIFT)
#define FROM_FP(x) ((x) >> FP_SHIFT)
```

### 11.3 水果物理

```c
fruit->x += fruit->vx;
fruit->y += fruit->vy;
fruit->vy += GRAVITY;
```

生成水果示例：

```c
fruit.x = TO_FP(rand_range(80, 560));
fruit.y = TO_FP(500);
fruit.vx = TO_FP(rand_range(-3, 3));
fruit.vy = TO_FP(rand_range(-13, -9));
fruit.radius = 28;
```

### 11.4 碰撞检测

Baseline 可以使用 bounding box：

```c
if (blade_active &&
    abs(blade_x - fruit_x) < fruit.radius + 20 &&
    abs(blade_y - fruit_y) < fruit.radius + 20) {
    slice_fruit(i);
}
```

推荐升级为 line segment vs circle：

```c
int segment_circle_hit(
    int x0, int y0,
    int x1, int y1,
    int cx, int cy,
    int r
);
```

刀轨迹使用上一帧刀位置到当前帧刀位置：

```text
P0 = previous blade position
P1 = current blade position
C  = fruit center
hit if distance(C, segment(P0, P1)) < fruit.radius
```

---

## 12. C 主循环伪代码

```c
int main(void) {
    hardware_init();
    game_init();

    while (1) {
        wait_for_frame_tick();

        Tracker t = read_tracker();
        update_blade(&blade, t);

        switch (game_state) {
        case GAME_START:
            update_start_screen();
            if (start_pressed() || blade.active) {
                start_game();
            }
            break;

        case GAME_PLAYING:
            maybe_spawn_fruit();
            update_fruits();

            for (int i = 0; i < MAX_FRUITS; ++i) {
                if (fruit_can_be_sliced(&fruits[i]) &&
                    blade.active &&
                    segment_circle_hit(
                        blade.prev_x, blade.prev_y,
                        blade.x, blade.y,
                        FROM_FP(fruits[i].x), FROM_FP(fruits[i].y),
                        fruits[i].radius)) {
                    slice_fruit(i);
                    score += fruit_score(fruits[i].type);
                }
            }

            update_effects();
            update_ui();
            write_sprite_table();
            commit_sprite_table();

            if (lives <= 0 || time_left <= 0) {
                game_state = GAME_OVER;
            }
            break;

        case GAME_OVER:
            update_game_over_screen();
            if (reset_pressed()) {
                game_init();
            }
            break;
        }
    }
}
```

---

## 13. 推荐源码目录结构

```text
project_root/
├── README.md
├── PROJECT_OVERVIEW_IMPLEMENTATION_PLAN.md
├── quartus/
│   ├── de2_115_fruit_ninja.qpf
│   ├── de2_115_fruit_ninja.qsf
│   └── constraints/
├── rtl/
│   ├── top.sv
│   ├── clock_reset/
│   │   ├── pll_system.sv
│   │   └── reset_sync.sv
│   ├── camera/
│   │   ├── ov2640_sccb_config.sv
│   │   ├── ov2640_reg_table.sv
│   │   ├── ov2640_capture.sv
│   │   └── rgb565_packer.sv
│   ├── memory/
│   │   ├── async_fifo.sv
│   │   ├── frame_buffer_writer.sv
│   │   ├── frame_buffer_reader.sv
│   │   └── frame_buffer_swap.sv
│   ├── tracking/
│   │   ├── color_prop_tracker.sv
│   │   └── tracker_cdc.sv
│   ├── video/
│   │   ├── vga_timing.sv
│   │   ├── vga_line_buffer.sv
│   │   ├── layer_compositor.sv
│   │   ├── sprite_engine.sv
│   │   ├── blade_renderer.sv
│   │   └── font_renderer.sv
│   ├── mmio/
│   │   ├── game_mmio.sv
│   │   └── sprite_table_regs.sv
│   └── common/
│       ├── sync_2ff.sv
│       ├── edge_detect.sv
│       └── fixed_point_pkg.sv
├── software/
│   ├── src/
│   │   ├── main.c
│   │   ├── game.c
│   │   ├── game.h
│   │   ├── fruit.c
│   │   ├── fruit.h
│   │   ├── collision.c
│   │   ├── collision.h
│   │   ├── mmio.h
│   │   ├── sprites.c
│   │   ├── sprites.h
│   │   ├── random.c
│   │   └── random.h
│   └── bsp/
├── assets/
│   ├── sprites/
│   ├── fonts/
│   └── converted_roms/
├── sim/
│   ├── tb_vga_timing.sv
│   ├── tb_color_prop_tracker.sv
│   ├── tb_sprite_engine.sv
│   └── tb_frame_buffer.sv
└── docs/
    ├── guidance.pdf
    ├── proposal.pdf
    ├── block_diagram.drawio
    └── debug_notes.md
```

---

## 14. HDL 模块清单与职责

### 14.1 `ov2640_sccb_config.sv`

功能：

- 通过 SCCB/I2C 写 OV2640 register table；
- 配置 RGB565 / QVGA；
- 输出 `config_done`；
- 提供 debug state。

关键接口：

```verilog
input  logic clk;
input  logic reset;
output logic sioc;
inout  wire  siod;
output logic config_done;
output logic [7:0] debug_state;
```

### 14.2 `ov2640_capture.sv`

功能：

- 在 `cam_pclk` 域采样 `CAM_D[7:0]`；
- 根据 VSYNC/HREF 生成 pixel 坐标；
- 两个 byte 合成 RGB565；
- 输出 `pix_valid`, `pix_x`, `pix_y`, `pix_rgb565`。

### 14.3 `color_prop_tracker.sv`

功能：

- 对摄像头像素流进行颜色阈值判断；
- 统计每帧 matching pixels 数量；
- 计算 bounding box；
- 输出道具中心点和 valid flag。

### 14.4 `frame_buffer_writer.sv`

功能：

- 接收 camera pixel stream；
- 通过 FIFO / Avalon master / SDRAM controller 写入当前 write buffer；
- frame done 时请求 buffer swap。

### 14.5 `frame_buffer_reader.sv`

功能：

- 根据 VGA 坐标计算 camera frame address；
- 从 SDRAM 读取 background pixel；
- 提供 line buffer，避免每个 VGA pixel 都访问 SDRAM；
- 输出 `camera_pixel` 给 compositor。

### 14.6 `vga_timing.sv`

功能：

- 生成 640×480 VGA timing；
- 输出 `vga_x`, `vga_y`, `active_video`, `hsync`, `vsync`, `vblank`。

### 14.7 `sprite_engine.sv`

功能：

- 读取 active sprite table；
- 对当前 VGA pixel 判断是否命中 sprite；
- 从 sprite ROM 读取像素；
- 处理 color key transparent；
- 输出 `sprite_hit`, `sprite_rgb`。

### 14.8 `blade_renderer.sv`

功能：

- 根据 blade position 绘制刀或 slash trail；
- 支持最近 N 个位置形成轨迹；
- 输出 `blade_hit`, `blade_rgb`。

### 14.9 `font_renderer.sv`

功能：

- 显示 score / timer / lives；
- 使用 font ROM；
- 输出 `ui_hit`, `ui_rgb`。

### 14.10 `layer_compositor.sv`

功能：

- 按优先级合成 background、fruit、effect、blade、UI；
- 输出最终 RGB 给 VGA DAC。

### 14.11 `game_mmio.sv`

功能：

- Avalon-MM slave；
- 暴露 tracker 状态、颜色阈值、game state、sprite table；
- 处理 Nios 与硬件同步。

---

## 15. 开发里程碑

### Milestone 1: VGA 基础输出

目标：

- VGA monitor 显示 color bars；
- timing 稳定；
- 可显示简单矩形和文字。

完成标准：

- 屏幕无闪烁；
- `vga_x/vga_y/hsync/vsync` 仿真正确；
- 可切换 debug pattern。

### Milestone 2: OV2640 初始化与采集

目标：

- SCCB 初始化成功；
- 能采集 RGB565 像素；
- 可以显示 test pattern 或真实图像。

完成标准：

- 摄像头输出稳定；
- 颜色基本正确；
- 图像无明显错位。

### Milestone 3: SDRAM frame buffer

目标：

- camera frame 写入 SDRAM；
- VGA 从 SDRAM 读取并显示；
- 实现 buffer swap。

完成标准：

- 画面稳定；
- 没有严重 tearing；
- 摄像头画面能镜像显示。

### Milestone 4: 颜色道具追踪

目标：

- 识别特定颜色物体；
- 计算中心点；
- 屏幕上绘制 blade cursor。

完成标准：

- 道具移动时刀跟随；
- 背景不会大量误识别；
- threshold 可通过寄存器调整。

### Milestone 5: 基础游戏

目标：

- 出现一个或多个几何水果；
- 刀划过水果后水果消失或切开；
- 分数增加。

完成标准：

- 游戏可玩；
- 碰撞检测稳定；
- score 显示正确。

### Milestone 6: 图形完善

目标：

- 水果 bitmap sprite；
- slash trail；
- sliced fruit animation；
- game start / game over screen。

完成标准：

- Demo 视觉效果完整；
- 无明显 frame drop；
- 最终报告可展示完整模块。

---

## 16. 调试模式建议

实现 `DEBUG_MODE` 寄存器或使用 board switches：

```text
DEBUG_MODE = 0: normal game
DEBUG_MODE = 1: VGA color bars
DEBUG_MODE = 2: raw camera feed
DEBUG_MODE = 3: camera feed + color mask overlay
DEBUG_MODE = 4: bounding box overlay
DEBUG_MODE = 5: sprite test
DEBUG_MODE = 6: font/UI test
```

颜色追踪 debug overlay：

- 被识别为道具的像素显示为亮绿色或白色；
- bounding box 用矩形框显示；
- center point 用十字显示；
- count 太低时显示 `NO PROP`。

---

## 17. 仿真计划

### 17.1 必做 testbench

- `tb_vga_timing.sv`
  - 检查 hsync/vsync timing；
  - 检查 active_video 区域；
  - 检查 frame counter。

- `tb_color_prop_tracker.sv`
  - 构造一帧 320×240 synthetic pixels；
  - 在特定区域放绿色/粉色块；
  - 检查 min/max/count/center 是否正确。

- `tb_sprite_engine.sv`
  - 测试 sprite inside/outside；
  - 测试 transparent color；
  - 测试 priority。

- `tb_game_mmio.sv`
  - 测试 Avalon-MM read/write；
  - 测试 threshold registers；
  - 测试 sprite commit。

### 17.2 可选 testbench

- `tb_ov2640_capture.sv`
  - 模拟 VSYNC/HREF/PCLK/D 数据；
  - 检查 RGB565 packing 和坐标。

- `tb_frame_buffer_swap.sv`
  - 模拟 camera frame_done 和 VGA vblank；
  - 检查 buffer index 不冲突。

---

## 18. SignalTap 观察信号

建议保存 SignalTap 配置，常用 probes：

### Camera

```text
CAM_VSYNC
CAM_HREF
CAM_PCLK sampled flag
cam_pix_valid
cam_pix_x
cam_pix_y
cam_rgb565
frame_start
frame_done
```

### Tracker

```text
is_prop
track_count
min_x, max_x
min_y, max_y
prop_valid
prop_cx, prop_cy
```

### SDRAM / Frame Buffer

```text
write_buf_id
read_buf_id
write_addr
read_addr
write_req
read_req
fifo_level
swap_pending
vblank
```

### VGA

```text
vga_x
vga_y
active_video
vblank
camera_pixel
sprite_hit
blade_hit
ui_hit
final_rgb
```

---

## 19. 风险与降级方案

### 19.1 OV2640 初始化失败

降级：

1. 先用 camera test pattern；
2. 使用已知可用的 OV2640 register table；
3. 降到 160×120；
4. 检查 SCCB ACK；
5. 检查 reset / pwdn / xclk。

### 19.2 画面颜色错误

优先检查：

1. RGB565 byte order；
2. R/G/B bit mapping；
3. VGA DAC bit width mapping；
4. OV2640 output format 是否真的是 RGB565。

### 19.3 画面撕裂

解决：

1. triple buffer；
2. vblank-only swap；
3. line buffer；
4. 降低 camera resolution；
5. 减少 SDRAM 访问冲突。

### 19.4 颜色识别误检

解决：

1. 使用更鲜艳的道具；
2. 加 threshold calibration 模式；
3. 增加 `PROP_COUNT_MIN`；
4. 对 bounding box 限制最大/最小尺寸；
5. demo 时控制光照和背景。

### 19.5 Sprite engine 来不及完成

降级：

1. 用圆形/方块水果代替 bitmap；
2. 用简单矩形 blade；
3. UI 只用 HEX 或简单 font；
4. 先完成可玩性，再加美术效果。

---

## 20. Claude Code 开发建议

当使用 Claude Code 协助开发时，请优先让它生成或修改以下内容：

### 20.1 适合 Claude Code 生成的内容

- SystemVerilog module skeleton；
- Avalon-MM register slave；
- VGA timing module；
- color tracker module；
- sprite descriptor structs；
- C game loop；
- collision detection C code；
- testbench；
- Python asset conversion scripts；
- README / docs。

### 20.2 需要人工重点检查的内容

- OV2640 register table 是否匹配硬件；
- DE2-115 pin assignment；
- PLL output clock；
- SDRAM controller timing；
- Avalon-MM address map；
- clock domain crossing；
- board-specific reset polarity；
- VGA DAC bit mapping。

### 20.3 给 Claude Code 的任务切分建议

不要一次要求它写完整工程。建议按以下顺序：

```text
1. Generate vga_timing.sv and tb_vga_timing.sv.
2. Generate color_prop_tracker.sv and tb_color_prop_tracker.sv.
3. Generate game_mmio.sv with the register map in this document.
4. Generate C headers for MMIO offsets.
5. Generate fruit physics and collision C modules.
6. Generate sprite_engine.sv skeleton.
7. Generate asset conversion script from PNG to RGB565 ROM.
8. Generate README build/debug instructions.
```

---

## 21. Definition of Done

项目最终 demo 至少应满足：

- VGA 能实时显示摄像头画面；
- 玩家拿特定颜色道具时，屏幕上有刀跟随；
- 至少一个水果/目标能在屏幕上运动；
- 刀划过水果后能检测碰撞；
- 分数能更新并显示；
- reset/start/game over 基本可用；
- 有清晰的 block diagram、module descriptions、C algorithm、hardware/software synchronization 说明；
- 有至少几个关键模块的仿真或 SignalTap 证据。

---

## 22. 当前推荐的最小可行版本

如果时间紧，最终应优先保证以下版本：

```text
Camera feed background
+ Color prop tracking
+ Blade cursor / slash line
+ Geometric fruit circles
+ Collision detection
+ Score display
```

真实水果 sprite、切开动画、炸弹、粒子和 alpha blending 都属于增强功能，不应阻塞 baseline demo。

---

## 23. 关键设计原则

1. 先让 VGA 显示稳定，再接摄像头。
2. 先显示 camera test pattern，再显示真实画面。
3. 先做颜色追踪，再做游戏逻辑。
4. 先用几何水果，再用 bitmap sprite。
5. 先用 color key transparency，再考虑 alpha blending。
6. Nios 不做逐像素处理。
7. 所有跨时钟域信号都必须同步。
8. 所有 buffer swap 都应在 vblank 或 frame boundary 发生。
9. 所有阈值参数都应可通过寄存器调整。
10. 每个模块都要有可独立 debug 的模式。

`include "rtl/game_overlay/color_prop_tracker.sv"
`include "rtl/game_overlay/fruit_sprite_rom.sv"
`include "rtl/game_overlay/fruit_sprite_rom_dual.sv"
`include "rtl/game_overlay/fruit_renderer.sv"
`include "rtl/game_overlay/slice_effect_state.sv"
`include "rtl/game_overlay/slice_effect_renderer.sv"
`include "rtl/game_overlay/ui_renderer.sv"
`include "rtl/game_overlay/knife_sprite_rom.sv"
`include "rtl/game_overlay/knife_trail_renderer.sv"
`include "rtl/game_overlay/knife_renderer.sv"
`include "rtl/game_overlay/ar_game_overlay.sv"

module final_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,

    input  logic [7:0]  CAM_D,
    input  logic        CAM_PCLK,
    input  logic        CAM_HREF,
    input  logic        CAM_VSYNC,
    output logic        CAM_PWDN,
    output logic        CAM_RESET_N,
    inout  wire         CAM_SIOC,
    inout  wire         CAM_SIOD,

    output logic        VGA_CLK,
    output logic        VGA_HS,
    output logic        VGA_VS,
    output logic        VGA_BLANK_N,
    output logic        VGA_SYNC_N,
    output logic [7:0]  VGA_R,
    output logic [7:0]  VGA_G,
    output logic [7:0]  VGA_B,

    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA,
    output logic        DRAM_CAS_N,
    output logic        DRAM_CKE,
    output logic        DRAM_CLK,
    output logic        DRAM_CS_N,
    inout  wire  [31:0] DRAM_DQ,
    output logic [3:0]  DRAM_DQM,
    output logic        DRAM_RAS_N,
    output logic        DRAM_WE_N,

    output logic [19:0] SRAM_ADDR,
    inout  wire  [15:0] SRAM_DQ,
    output logic        SRAM_CE_N,
    output logic        SRAM_OE_N,
    output logic        SRAM_WE_N,
    output logic        SRAM_UB_N,
    output logic        SRAM_LB_N
);

    localparam logic DEBUG_SRAM_TEST = 1'b0;
    localparam logic ENABLE_GAME_OVERLAY = 1'b1;
    localparam logic ENABLE_PROP_TRACKER = 1'b1;
    localparam logic ENABLE_KNIFE_SPRITE = 1'b1;
    localparam logic ENABLE_KNIFE_TRAIL = 1'b0;
    localparam logic ENABLE_PROP_BBOX_DEBUG = 1'b1;
    localparam logic SHOW_CAMERA_BACKGROUND = 1'b1;
    localparam logic SHOW_TRACKER_MASK = 1'b1;

    logic        reset;
    logic [1:0]  cam_ctrl;
    logic        i2c_sda_in;
    logic        i2c_scl_in;
    logic        i2c_sda_oe;
    logic        i2c_scl_oe;

    (* keep = "true", preserve *) logic [9:0]  draw_x;
    (* keep = "true", preserve *) logic [9:0]  draw_y;
    (* keep = "true", preserve *) logic        cam_fifo_wr_valid;
    (* keep = "true", preserve *) logic        cam_fifo_wr_ready;
    (* keep = "true", preserve *) logic [17:0] cam_fifo_wr_data;
    logic        cam_fifo_rd_valid;
    logic        cam_fifo_rd_ready;
    logic [17:0] cam_fifo_rd_data;
    logic        cam_overflow;
    (* keep = "true", preserve *) logic        cam_overflow_pulse;
    (* keep = "true", preserve *) logic        cam_drop_frame;
    (* keep = "true", preserve *) logic [31:0] cam_overflow_count;
    (* keep = "true", preserve *) logic [31:0] cam_accepted_pixel_count;
    (* keep = "true", preserve *) logic        cam_fifo_wr_full;
    (* keep = "true", preserve *) logic        cam_fifo_rd_empty;
    (* keep = "true", preserve *) logic [11:0] cam_fifo_wr_level;
    (* keep = "true", preserve *) logic [11:0] cam_fifo_rd_level;
    logic        test_fifo_valid;
    logic        test_fifo_ready;
    logic [17:0] test_fifo_data;
    logic        writer_fifo_valid;
    logic        writer_fifo_ready;
    logic [17:0] writer_fifo_data;

    (* keep = "true", preserve *) logic        mem_wr_valid;
    (* keep = "true", preserve *) logic        mem_wr_ready;
    (* keep = "true", preserve *) logic [19:0] mem_wr_addr;
    (* keep = "true", preserve *) logic [15:0] mem_wr_data;
    (* keep = "true", preserve *) logic        mem_rd_req;
    (* keep = "true", preserve *) logic        mem_rd_ready;
    (* keep = "true", preserve *) logic [19:0] mem_rd_addr;
    (* keep = "true", preserve *) logic        mem_rd_valid;
    (* keep = "true", preserve *) logic [15:0] mem_rd_data;
    (* keep = "true", preserve *) logic [31:0] mem_wr_accept_count;
    (* keep = "true", preserve *) logic [31:0] mem_rd_accept_count;
    (* keep = "true", preserve *) logic        fb_mem_rd_req;
    (* keep = "true", preserve *) logic        fb_mem_rd_ready;
    (* keep = "true", preserve *) logic [19:0] fb_mem_rd_addr;
    (* keep = "true", preserve *) logic        fb_mem_rd_valid;
    (* keep = "true", preserve *) logic [15:0] fb_mem_rd_data;
    (* keep = "true", preserve *) logic [1:0]  read_frame;
    (* keep = "true", preserve *) logic [1:0]  pending_frame;
    (* keep = "true", preserve *) logic        pending_valid;
    (* keep = "true", preserve *) logic        pending_consumed;
    (* keep = "true", preserve *) logic [31:0] writer_accepted_pixel_count;
    (* keep = "true", preserve *) logic [31:0] writer_completed_frame_count;
    (* keep = "true", preserve *) logic [31:0] writer_dropped_frame_count;
    (* keep = "true", preserve *) logic [16:0] writer_debug_pixel_count;
    (* keep = "true", preserve *) logic [15:0] vga_pixel;
    (* keep = "true", preserve *) logic [15:0] vga_pixel_debug;
    (* keep = "true", preserve *) logic        vga_pixel_valid;
    (* keep = "true", preserve *) logic [7:0]  cam_r;
    (* keep = "true", preserve *) logic [7:0]  cam_g;
    (* keep = "true", preserve *) logic [7:0]  cam_b;
    logic        tracker_mask_pixel;
    logic [7:0]  pat_r;
    logic [7:0]  pat_g;
    logic [7:0]  pat_b;
    logic [7:0]  base_r;
    logic [7:0]  base_g;
    logic [7:0]  base_b;
    logic [7:0]  last_cam_r;
    logic [7:0]  last_cam_g;
    logic [7:0]  last_cam_b;
    logic [7:0]  overlay_r;
    logic [7:0]  overlay_g;
    logic [7:0]  overlay_b;
    logic [7:0]  vga_r_next;
    logic [7:0]  vga_g_next;
    logic [7:0]  vga_b_next;
    logic [7:0]  trail_overlay_r;
    logic [7:0]  trail_overlay_g;
    logic [7:0]  trail_overlay_b;
    logic [7:0]  knife_overlay_r;
    logic [7:0]  knife_overlay_g;
    logic [7:0]  knife_overlay_b;
    logic        vga_clk;
    (* keep = "true", preserve *) logic        have_sram_frame;
    (* keep = "true", preserve *) logic        sram_display_enable;
    (* keep = "true", preserve *) logic        display_sram_pixel;
    (* keep = "true", preserve *) logic [2:0]  color_debug_mode;
    (* keep = "true", preserve *) logic        debug_cam_backpressure;
    (* keep = "true", preserve *) logic        debug_vga_active;
    (* keep = "true", preserve *) logic        debug_vga_visible_miss;
    logic [31:0] frame_counter_pio;
    logic [31:0] tracker_status_pio;
    logic [31:0] game_ctrl_pio;
    logic [31:0] fruit0_desc_pio;
    logic [31:0] fruit1_desc_pio;
    logic [31:0] fruit2_desc_pio;
    logic [31:0] fruit3_desc_pio;
    logic [31:0] effect_event_pio;
    logic        frame_tick_vga;
    logic        frame_tick_toggle_vga;
    logic [2:0]  frame_tick_sync;
    logic        frame_tick_50;
    logic        tracker_frame_start;
    logic        tracker_frame_end;
    logic        tracker_stream_frame_start;
    logic        tracker_stream_frame_end;
    logic        tracker_stream_valid;
    logic [9:0]  tracker_stream_x;
    logic [9:0]  tracker_stream_y;
    logic [15:0] tracker_stream_rgb565;
    logic        tracker_camera_accept;
    logic [8:0]  tracker_camera_x;
    logic [8:0]  tracker_camera_y;
    logic        tracker_result_pending;
    logic [5:0]  tracker_result_delay;
    logic        tracker_result_ready;
    logic [2:0]  tracker_result_sync_vga;
    logic        tracker_result_ready_vga;
    logic        tracker_sample_toggle_vga;
    logic [2:0]  tracker_sample_sync;
    logic        tracker_sample_50;
    logic        prop_valid_vga;
    logic [9:0]  prop_x_vga;
    logic [9:0]  prop_y_vga;
    logic [9:0]  prop_min_x_vga;
    logic [9:0]  prop_min_y_vga;
    logic [9:0]  prop_max_x_vga;
    logic [9:0]  prop_max_y_vga;
    logic [15:0] prop_count_vga;
    logic        prop_result_valid_cam;
    logic [9:0]  prop_result_x_cam;
    logic [9:0]  prop_result_y_cam;
    logic [9:0]  prop_result_min_x_cam;
    logic [9:0]  prop_result_min_y_cam;
    logic [9:0]  prop_result_max_x_cam;
    logic [9:0]  prop_result_max_y_cam;
    logic [15:0] prop_result_count_cam;
    logic        prop_bbox_valid;
    logic [9:0]  prop_bbox_min_x;
    logic [9:0]  prop_bbox_min_y;
    logic [9:0]  prop_bbox_max_x;
    logic [9:0]  prop_bbox_max_y;
    logic [9:0]  prop_bbox_x;
    logic [9:0]  prop_bbox_y;
    logic        prop_bbox_h_edge;
    logic        prop_bbox_v_edge;
    logic        prop_bbox_rect_hit;
    logic        knife_center_valid;
    logic [9:0]  knife_center_x;
    logic [9:0]  knife_center_y;
    logic [3:0]  prop_miss_frames;

    assign reset = ~KEY[0];
    assign VGA_CLK = vga_clk;

    always_ff @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            vga_clk <= 1'b0;
        end else begin
            vga_clk <= ~vga_clk;
        end
    end

    assign CAM_PWDN = DEBUG_SRAM_TEST ? 1'b1 : cam_ctrl[0];
    assign CAM_RESET_N = DEBUG_SRAM_TEST ? 1'b0 : cam_ctrl[1];

    assign CAM_SIOD = DEBUG_SRAM_TEST ? 1'bz : (i2c_sda_oe ? 1'b0 : 1'bz);
    assign CAM_SIOC = DEBUG_SRAM_TEST ? 1'bz : (i2c_scl_oe ? 1'b0 : 1'bz);
    assign i2c_sda_in = CAM_SIOD;
    assign i2c_scl_in = CAM_SIOC;
    assign color_debug_mode = 3'b000;
    assign debug_cam_backpressure = cam_fifo_wr_valid && !cam_fifo_wr_ready;
    assign debug_vga_active = VGA_BLANK_N && (draw_x < 10'd640) && (draw_y < 10'd480);
    assign debug_vga_visible_miss = debug_vga_active && sram_display_enable && !vga_pixel_valid;
    assign frame_tick_vga = (draw_x == 10'd0) && (draw_y == 10'd0);
    assign tracker_frame_start = frame_tick_vga;
    assign tracker_frame_end = VGA_BLANK_N && (draw_x == 10'd639) && (draw_y == 10'd479);

    project_soc soc (
        .cam_ctrl_export         (cam_ctrl),
        .clk_clk                 (CLOCK_50),
        .effect_event_pio_external_connection_export   (effect_event_pio),
        .frame_counter_pio_external_connection_export  (frame_counter_pio),
        .fruit0_desc_pio_external_connection_export    (fruit0_desc_pio),
        .fruit1_desc_pio_external_connection_export    (fruit1_desc_pio),
        .fruit2_desc_pio_external_connection_export    (fruit2_desc_pio),
        .fruit3_desc_pio_external_connection_export    (fruit3_desc_pio),
        .game_ctrl_pio_external_connection_export      (game_ctrl_pio),
        .i2c_0_i2c_serial_sda_in (i2c_sda_in),
        .i2c_0_i2c_serial_scl_in (i2c_scl_in),
        .i2c_0_i2c_serial_sda_oe (i2c_sda_oe),
        .i2c_0_i2c_serial_scl_oe (i2c_scl_oe),
        .keys_export             (KEY),
        .reset_reset_n           (KEY[0]),
        .sdram_clk_clk           (DRAM_CLK),
        .sdram_wire_addr         (DRAM_ADDR),
        .sdram_wire_ba           (DRAM_BA),
        .sdram_wire_cas_n        (DRAM_CAS_N),
        .sdram_wire_cke          (DRAM_CKE),
        .sdram_wire_cs_n         (DRAM_CS_N),
        .sdram_wire_dq           (DRAM_DQ),
        .sdram_wire_dqm          (DRAM_DQM),
        .sdram_wire_ras_n        (DRAM_RAS_N),
        .sdram_wire_we_n         (DRAM_WE_N),
        .tracker_status_pio_external_connection_export (tracker_status_pio)
    );

    always_ff @(posedge vga_clk or posedge reset) begin
        if (reset) begin
            frame_tick_toggle_vga <= 1'b0;
        end else if (frame_tick_vga) begin
            frame_tick_toggle_vga <= ~frame_tick_toggle_vga;
        end
    end

    always_ff @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            frame_tick_sync <= 3'b000;
            frame_counter_pio <= 32'd0;
        end else begin
            frame_tick_sync <= {frame_tick_sync[1:0], frame_tick_toggle_vga};

            if (frame_tick_50) begin
                frame_counter_pio <= frame_counter_pio + 32'd1;
            end
        end
    end

    assign frame_tick_50 = frame_tick_sync[2] ^ frame_tick_sync[1];

    VGA_controller vga_controller (
        .Clk         (CLOCK_50),
        .Reset       (reset),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_CLK     (vga_clk),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .DrawX       (draw_x),
        .DrawY       (draw_y)
    );

    ov2640_capture camera_capture (
        .pclk          (CAM_PCLK),
        .reset         (reset),
        .cam_d         (CAM_D),
        .cam_href      (CAM_HREF),
        .cam_vsync     (CAM_VSYNC),
        .fifo_wr_valid (cam_fifo_wr_valid),
        .fifo_wr_ready (cam_fifo_wr_ready),
        .fifo_wr_data  (cam_fifo_wr_data),
        .overflow      (cam_overflow),
        .overflow_pulse (cam_overflow_pulse),
        .drop_frame    (cam_drop_frame),
        .overflow_count (cam_overflow_count),
        .accepted_pixel_count (cam_accepted_pixel_count)
    );

    async_fifo #(
        .DATA_WIDTH (18),
        .ADDR_WIDTH (11)
    ) camera_fifo (
        .wr_clk    (CAM_PCLK),
        .wr_reset  (reset),
        .wr_valid  (cam_fifo_wr_valid),
        .wr_ready  (cam_fifo_wr_ready),
        .wr_data   (cam_fifo_wr_data),
        .rd_clk    (vga_clk),
        .rd_reset  (reset),
        .rd_valid  (cam_fifo_rd_valid),
        .rd_ready  (cam_fifo_rd_ready),
        .rd_data   (cam_fifo_rd_data),
        .wr_full   (cam_fifo_wr_full),
        .rd_empty  (cam_fifo_rd_empty),
        .wr_level  (cam_fifo_wr_level),
        .rd_level  (cam_fifo_rd_level)
    );

    sram_test_source sram_test (
        .clk        (vga_clk),
        .reset      (reset),
        .mode       (~KEY[2:1]),
        .fifo_valid (test_fifo_valid),
        .fifo_ready (test_fifo_ready),
        .fifo_data  (test_fifo_data)
    );

    assign writer_fifo_valid = DEBUG_SRAM_TEST ? test_fifo_valid : cam_fifo_rd_valid;
    assign writer_fifo_data = DEBUG_SRAM_TEST ? test_fifo_data : cam_fifo_rd_data;
    assign test_fifo_ready = DEBUG_SRAM_TEST ? writer_fifo_ready : 1'b0;
    assign cam_fifo_rd_ready = DEBUG_SRAM_TEST ? 1'b0 : writer_fifo_ready;
    assign tracker_camera_accept = !DEBUG_SRAM_TEST && cam_fifo_wr_valid;

    sram_frame_writer frame_writer (
        .clk              (vga_clk),
        .reset            (reset),
        .fifo_valid       (writer_fifo_valid),
        .fifo_ready       (writer_fifo_ready),
        .fifo_data        (writer_fifo_data),
        .mem_wr_valid     (mem_wr_valid),
        .mem_wr_ready     (mem_wr_ready),
        .mem_wr_addr      (mem_wr_addr),
        .mem_wr_data      (mem_wr_data),
        .read_frame       (read_frame),
        .pending_consumed (pending_consumed),
        .pending_frame    (pending_frame),
        .pending_valid    (pending_valid),
        .accepted_pixel_count (writer_accepted_pixel_count),
        .completed_frame_count (writer_completed_frame_count),
        .dropped_frame_count (writer_dropped_frame_count),
        .debug_pixel_count (writer_debug_pixel_count)
    );

    vga_framebuffer_reader framebuffer_reader (
        .clk              (vga_clk),
        .reset            (reset),
        .draw_x           (draw_x),
        .draw_y           (draw_y),
        .blank_n          (VGA_BLANK_N),
        .pending_frame    (pending_frame),
        .pending_valid    (pending_valid),
        .pending_consumed (pending_consumed),
        .read_frame       (read_frame),
        .mem_rd_req       (fb_mem_rd_req),
        .mem_rd_ready     (fb_mem_rd_ready),
        .mem_rd_addr      (fb_mem_rd_addr),
        .mem_rd_valid     (fb_mem_rd_valid),
        .mem_rd_data      (fb_mem_rd_data),
        .pixel            (vga_pixel),
        .pixel_valid      (vga_pixel_valid)
    );

    assign sram_display_enable = have_sram_frame;

    assign mem_rd_req = sram_display_enable && fb_mem_rd_req;
    assign mem_rd_addr = fb_mem_rd_addr;
    assign fb_mem_rd_ready = sram_display_enable && mem_rd_ready;
    assign fb_mem_rd_valid = sram_display_enable && mem_rd_valid;
    assign fb_mem_rd_data = mem_rd_data;

    sram_arbiter sram (
        .clk        (vga_clk),
        .reset      (reset),
        .wr_valid   (mem_wr_valid),
        .wr_ready   (mem_wr_ready),
        .wr_addr    (mem_wr_addr),
        .wr_data    (mem_wr_data),
        .rd_req     (mem_rd_req),
        .rd_ready   (mem_rd_ready),
        .rd_addr    (mem_rd_addr),
        .rd_valid   (mem_rd_valid),
        .rd_data    (mem_rd_data),
        .wr_accept_count (mem_wr_accept_count),
        .rd_accept_count (mem_rd_accept_count),
        .SRAM_ADDR  (SRAM_ADDR),
        .SRAM_DQ    (SRAM_DQ),
        .SRAM_CE_N  (SRAM_CE_N),
        .SRAM_OE_N  (SRAM_OE_N),
        .SRAM_WE_N  (SRAM_WE_N),
        .SRAM_UB_N  (SRAM_UB_N),
        .SRAM_LB_N  (SRAM_LB_N)
    );

    function automatic logic [15:0] swap_rgb565_bytes(input logic [15:0] pixel);
        swap_rgb565_bytes = {pixel[7:0], pixel[15:8]};
    endfunction

    function automatic logic [15:0] swap_rgb565_rb(input logic [15:0] pixel);
        swap_rgb565_rb = {pixel[4:0], pixel[10:5], pixel[15:11]};
    endfunction

    function automatic logic [7:0] reverse8(input logic [7:0] value);
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                reverse8[i] = value[7 - i];
            end
        end
    endfunction

    function automatic logic [15:0] reverse_rgb565_byte_bits(input logic [15:0] pixel);
        reverse_rgb565_byte_bits = {reverse8(pixel[15:8]), reverse8(pixel[7:0])};
    endfunction

    function automatic logic green_mask_rgb565(
        input logic [15:0] pixel,
        input logic [9:0]  pixel_x,
        input logic [9:0]  pixel_y
    );
        logic [4:0] r5_m;
        logic [5:0] g6_m;
        logic [4:0] b5_m;
        logic [6:0] r7_m;
        logic [6:0] g7_m;
        logic [6:0] b7_m;
        logic [7:0] green2_m;
        logic [7:0] rb_sum_m;
        begin
            r5_m = pixel[15:11];
            g6_m = pixel[10:5];
            b5_m = pixel[4:0];
            r7_m = {1'b0, r5_m, 1'b0};
            g7_m = {1'b0, g6_m};
            b7_m = {1'b0, b5_m, 1'b0};
            green2_m = {g7_m, 1'b0};
            rb_sum_m = {1'b0, r7_m} + {1'b0, b7_m};

            green_mask_rgb565 = (r5_m <= 5'd18) &&
                                (g6_m >= 6'd12) &&
                                (b5_m <= 5'd23) &&
                                (g7_m > (r7_m + 7'd9)) &&
                                ((g7_m + 7'd6) > b7_m) &&
                                (green2_m > (rb_sum_m + 8'd10));
        end
    endfunction

    always_comb begin
        vga_pixel_debug = vga_pixel;

        if (color_debug_mode[2]) begin
            vga_pixel_debug = reverse_rgb565_byte_bits(vga_pixel_debug);
        end

        if (color_debug_mode[0]) begin
            vga_pixel_debug = swap_rgb565_bytes(vga_pixel_debug);
        end

        if (color_debug_mode[1]) begin
            vga_pixel_debug = swap_rgb565_rb(vga_pixel_debug);
        end
    end

    rgb_lut rgb_expand (
        .rgb565 (vga_pixel_debug),
        .r8     (cam_r),
        .g8     (cam_g),
        .b8     (cam_b)
    );

    assign tracker_mask_pixel = green_mask_rgb565(vga_pixel_debug, draw_x, draw_y);

    vga_test_pattern fallback_pattern (
        .draw_x (draw_x),
        .draw_y (draw_y),
        .r      (pat_r),
        .g      (pat_g),
        .b      (pat_b)
    );

    always_ff @(posedge CAM_PCLK or posedge reset) begin
        if (reset) begin
            tracker_stream_frame_start <= 1'b0;
            tracker_stream_frame_end <= 1'b0;
            tracker_stream_valid <= 1'b0;
            tracker_stream_x <= 10'd0;
            tracker_stream_y <= 10'd0;
            tracker_stream_rgb565 <= 16'd0;
            tracker_camera_x <= 9'd0;
            tracker_camera_y <= 9'd0;
        end else begin
            tracker_stream_frame_start <= 1'b0;
            tracker_stream_frame_end <= 1'b0;
            tracker_stream_valid <= 1'b0;

            if (tracker_camera_accept) begin
                tracker_stream_frame_start <= cam_fifo_wr_data[17];
                tracker_stream_valid <= 1'b1;
                tracker_stream_rgb565 <= cam_fifo_wr_data[15:0];

                if (cam_fifo_wr_data[17]) begin
                    tracker_stream_x <= {9'd0, 1'b1};
                    tracker_stream_y <= {9'd0, 1'b1};
                    tracker_camera_x <= 9'd1;
                    tracker_camera_y <= 9'd0;
                end else begin
                    tracker_stream_x <= {tracker_camera_x, 1'b1};
                    tracker_stream_y <= {tracker_camera_y, 1'b1};
                    tracker_stream_frame_end <= (tracker_camera_x == 9'd319) &&
                                                (tracker_camera_y == 9'd239);

                    if (tracker_camera_x == 9'd319) begin
                        tracker_camera_x <= 9'd0;
                        if (tracker_camera_y == 9'd239) begin
                            tracker_camera_y <= 9'd0;
                        end else begin
                            tracker_camera_y <= tracker_camera_y + 9'd1;
                        end
                    end else begin
                        tracker_camera_x <= tracker_camera_x + 9'd1;
                    end
                end
            end
        end
    end

    generate
        if (ENABLE_PROP_TRACKER) begin : gen_prop_tracker
            color_prop_tracker prop_tracker (
                .clk              (CAM_PCLK),
                .reset            (reset),
                .frame_start      (tracker_stream_frame_start),
                .frame_end        (tracker_stream_frame_end),
                .pix_valid        (tracker_stream_valid),
                .pix_x            (tracker_stream_x),
                .pix_y            (tracker_stream_y),
                .pix_rgb565       (tracker_stream_rgb565),
                .r_min            (5'd0),
                .r_max            (5'd18),
                .g_min            (6'd12),
                .g_max            (6'd63),
                .b_min            (5'd0),
                .b_max            (5'd23),
                .dominance_margin (6'd9),
                .blue_margin      (6'd6),
                .count_min        (16'd6),
                .prop_valid       (prop_valid_vga),
                .prop_x           (prop_x_vga),
                .prop_y           (prop_y_vga),
                .bbox_min_x       (prop_min_x_vga),
                .bbox_min_y       (prop_min_y_vga),
                .bbox_max_x       (prop_max_x_vga),
                .bbox_max_y       (prop_max_y_vga),
                .prop_count       (prop_count_vga)
            );
        end else begin : gen_no_prop_tracker
            assign prop_valid_vga = 1'b0;
            assign prop_x_vga = 10'd0;
            assign prop_y_vga = 10'd0;
            assign prop_min_x_vga = 10'd0;
            assign prop_min_y_vga = 10'd0;
            assign prop_max_x_vga = 10'd0;
            assign prop_max_y_vga = 10'd0;
            assign prop_count_vga = 16'd0;
        end
    endgenerate

    always_ff @(posedge CAM_PCLK or posedge reset) begin
        if (reset) begin
            tracker_result_pending <= 1'b0;
            tracker_result_delay <= 6'd0;
            tracker_result_ready <= 1'b0;
            tracker_sample_toggle_vga <= 1'b0;
            prop_result_valid_cam <= 1'b0;
            prop_result_x_cam <= 10'd0;
            prop_result_y_cam <= 10'd0;
            prop_result_min_x_cam <= 10'd0;
            prop_result_min_y_cam <= 10'd0;
            prop_result_max_x_cam <= 10'd0;
            prop_result_max_y_cam <= 10'd0;
            prop_result_count_cam <= 16'd0;
        end else if (!ENABLE_PROP_TRACKER) begin
            tracker_result_pending <= 1'b0;
            tracker_result_delay <= 6'd0;
            tracker_result_ready <= 1'b0;
            tracker_sample_toggle_vga <= 1'b0;
            prop_result_valid_cam <= 1'b0;
            prop_result_x_cam <= 10'd0;
            prop_result_y_cam <= 10'd0;
            prop_result_min_x_cam <= 10'd0;
            prop_result_min_y_cam <= 10'd0;
            prop_result_max_x_cam <= 10'd0;
            prop_result_max_y_cam <= 10'd0;
            prop_result_count_cam <= 16'd0;
        end else begin
            tracker_result_ready <= 1'b0;

            if (tracker_stream_frame_end) begin
                tracker_result_pending <= 1'b1;
                tracker_result_delay <= 6'd2;
            end else if (tracker_result_pending) begin
                if (tracker_result_delay == 6'd0) begin
                    tracker_result_pending <= 1'b0;
                    tracker_result_ready <= 1'b1;
                    prop_result_valid_cam <= prop_valid_vga;
                    prop_result_x_cam <= prop_x_vga;
                    prop_result_y_cam <= prop_y_vga;
                    prop_result_min_x_cam <= prop_min_x_vga;
                    prop_result_min_y_cam <= prop_min_y_vga;
                    prop_result_max_x_cam <= prop_max_x_vga;
                    prop_result_max_y_cam <= prop_max_y_vga;
                    prop_result_count_cam <= prop_count_vga;
                    tracker_sample_toggle_vga <= ~tracker_sample_toggle_vga;
                end else begin
                    tracker_result_delay <= tracker_result_delay - 6'd1;
                end
            end
        end
    end

    always_ff @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            tracker_sample_sync <= 3'b000;
            tracker_status_pio <= 32'd0;
        end else if (!ENABLE_PROP_TRACKER) begin
            tracker_sample_sync <= 3'b000;
            tracker_status_pio <= 32'd0;
        end else begin
            tracker_sample_sync <= {tracker_sample_sync[1:0], tracker_sample_toggle_vga};

            if (tracker_sample_50) begin
                tracker_status_pio <= {
                    tracker_sample_sync[2],
                    prop_result_valid_cam,
                    prop_result_x_cam,
                    prop_result_y_cam,
                    prop_result_count_cam[15:6]
                };
            end
        end
    end

    assign tracker_sample_50 = tracker_sample_sync[2] ^ tracker_sample_sync[1];

    always_ff @(posedge vga_clk or posedge reset) begin
        if (reset) begin
            tracker_result_sync_vga <= 3'b000;
            tracker_result_ready_vga <= 1'b0;
        end else if (!ENABLE_PROP_TRACKER) begin
            tracker_result_sync_vga <= 3'b000;
            tracker_result_ready_vga <= 1'b0;
        end else begin
            tracker_result_sync_vga <= {tracker_result_sync_vga[1:0], tracker_sample_toggle_vga};
            tracker_result_ready_vga <= tracker_result_sync_vga[2] ^ tracker_result_sync_vga[1];
        end
    end

    always_ff @(posedge vga_clk or posedge reset) begin
        if (reset) begin
            prop_bbox_valid <= 1'b0;
            prop_bbox_min_x <= 10'd0;
            prop_bbox_min_y <= 10'd0;
            prop_bbox_max_x <= 10'd0;
            prop_bbox_max_y <= 10'd0;
            knife_center_valid <= 1'b0;
            knife_center_x <= 10'd24;
            knife_center_y <= 10'd24;
            prop_miss_frames <= 4'd0;
        end else if (!ENABLE_PROP_TRACKER) begin
            prop_bbox_valid <= 1'b0;
            prop_bbox_min_x <= 10'd0;
            prop_bbox_min_y <= 10'd0;
            prop_bbox_max_x <= 10'd0;
            prop_bbox_max_y <= 10'd0;
            knife_center_valid <= 1'b0;
            knife_center_x <= 10'd24;
            knife_center_y <= 10'd24;
            prop_miss_frames <= 4'd0;
        end else if (tracker_result_ready_vga) begin
            prop_bbox_valid <= prop_result_valid_cam;

            if (prop_result_valid_cam) begin
                knife_center_valid <= 1'b1;
                prop_miss_frames <= 4'd0;
                prop_bbox_min_x <= prop_result_min_x_cam;
                prop_bbox_min_y <= prop_result_min_y_cam;
                prop_bbox_max_x <= prop_result_max_x_cam;
                prop_bbox_max_y <= prop_result_max_y_cam;

                if (prop_result_x_cam < 10'd24) begin
                    knife_center_x <= 10'd24;
                end else if (prop_result_x_cam > 10'd615) begin
                    knife_center_x <= 10'd615;
                end else begin
                    knife_center_x <= prop_result_x_cam;
                end

                if (prop_result_y_cam < 10'd24) begin
                    knife_center_y <= 10'd24;
                end else if (prop_result_y_cam > 10'd455) begin
                    knife_center_y <= 10'd455;
                end else begin
                    knife_center_y <= prop_result_y_cam;
                end
            end else begin
                knife_center_valid <= 1'b0;
                prop_miss_frames <= 4'd0;
            end
        end
    end

    assign prop_bbox_h_edge = prop_bbox_valid &&
                              (draw_x >= prop_bbox_min_x) &&
                              (draw_x <= prop_bbox_max_x) &&
                              (((draw_y >= prop_bbox_min_y) && (draw_y <= prop_bbox_min_y + 10'd1)) ||
                               ((draw_y <= prop_bbox_max_y) && (draw_y + 10'd1 >= prop_bbox_max_y)));
    assign prop_bbox_v_edge = prop_bbox_valid &&
                              (draw_y >= prop_bbox_min_y) &&
                              (draw_y <= prop_bbox_max_y) &&
                              (((draw_x >= prop_bbox_min_x) && (draw_x <= prop_bbox_min_x + 10'd1)) ||
                               ((draw_x <= prop_bbox_max_x) && (draw_x + 10'd1 >= prop_bbox_max_x)));
    assign prop_bbox_rect_hit = ENABLE_PROP_BBOX_DEBUG && ENABLE_PROP_TRACKER &&
                                VGA_BLANK_N && (prop_bbox_h_edge || prop_bbox_v_edge);
    assign prop_bbox_x = ({1'b0, prop_bbox_min_x} + {1'b0, prop_bbox_max_x}) >> 1;
    assign prop_bbox_y = ({1'b0, prop_bbox_min_y} + {1'b0, prop_bbox_max_y}) >> 1;

    always_ff @(posedge vga_clk or posedge reset) begin
        if (reset) begin
            have_sram_frame <= 1'b0;
        end else if (pending_valid) begin
            have_sram_frame <= 1'b1;
        end else if (pending_consumed) begin
            have_sram_frame <= 1'b1;
        end
    end

    assign display_sram_pixel = sram_display_enable && vga_pixel_valid;

    always_ff @(posedge vga_clk or posedge reset) begin
        if (reset) begin
            last_cam_r <= 8'h00;
            last_cam_g <= 8'h00;
            last_cam_b <= 8'h00;
        end else if (display_sram_pixel) begin
            last_cam_r <= cam_r;
            last_cam_g <= cam_g;
            last_cam_b <= cam_b;
        end
    end

    always_comb begin
        if (!VGA_BLANK_N) begin
            base_r = 8'h00;
            base_g = 8'h00;
            base_b = 8'h00;
        end else if (SHOW_CAMERA_BACKGROUND && display_sram_pixel) begin
            if (SHOW_TRACKER_MASK) begin
                base_r = tracker_mask_pixel ? 8'hff : 8'h00;
                base_g = tracker_mask_pixel ? 8'hff : 8'h00;
                base_b = tracker_mask_pixel ? 8'hff : 8'h00;
            end else begin
                base_r = cam_r;
                base_g = cam_g;
                base_b = cam_b;
            end
        end else if (SHOW_CAMERA_BACKGROUND && sram_display_enable) begin
            if (SHOW_TRACKER_MASK) begin
                base_r = 8'h00;
                base_g = 8'h00;
                base_b = 8'h00;
            end else begin
                base_r = last_cam_r;
                base_g = last_cam_g;
                base_b = last_cam_b;
            end
        end else if (!SHOW_CAMERA_BACKGROUND) begin
            base_r = 8'h00;
            base_g = 8'h00;
            base_b = 8'h00;
        end else begin
            base_r = pat_r;
            base_g = pat_g;
            base_b = pat_b;
        end
    end

    generate
        if (ENABLE_GAME_OVERLAY) begin : gen_game_overlay
            ar_game_overlay overlay (
                .clk              (vga_clk),
                .reset            (reset),
                .draw_x           (draw_x),
                .draw_y           (draw_y),
                .blank_n          (VGA_BLANK_N),
                .bg_r             (base_r),
                .bg_g             (base_g),
                .bg_b             (base_b),
                .game_ctrl_pio    (game_ctrl_pio),
                .fruit0_desc_pio  (fruit0_desc_pio),
                .fruit1_desc_pio  (fruit1_desc_pio),
                .fruit2_desc_pio  (fruit2_desc_pio),
                .fruit3_desc_pio  (fruit3_desc_pio),
                .effect_event_pio (effect_event_pio),
                .out_r            (overlay_r),
                .out_g            (overlay_g),
                .out_b            (overlay_b)
            );
        end else begin : gen_no_game_overlay
            assign overlay_r = base_r;
            assign overlay_g = base_g;
            assign overlay_b = base_b;
        end
    endgenerate

    always_comb begin
        if (!VGA_BLANK_N) begin
            vga_r_next = 8'h00;
            vga_g_next = 8'h00;
            vga_b_next = 8'h00;
        end else if (prop_bbox_rect_hit) begin
            vga_r_next = 8'hff;
            vga_g_next = 8'h00;
            vga_b_next = 8'hff;
        end else begin
            vga_r_next = overlay_r;
            vga_g_next = overlay_g;
            vga_b_next = overlay_b;
        end
    end

    generate
        if (ENABLE_KNIFE_TRAIL) begin : gen_knife_trail
            knife_trail_renderer knife_trail_renderer_inst (
                .clk         (vga_clk),
                .reset       (reset),
                .frame_tick  (frame_tick_vga),
                .knife_valid (ENABLE_KNIFE_SPRITE && ENABLE_PROP_TRACKER && knife_center_valid),
                .knife_x     (knife_center_x),
                .knife_y     (knife_center_y),
                .draw_x      (draw_x),
                .draw_y      (draw_y),
                .bg_r        (vga_r_next),
                .bg_g        (vga_g_next),
                .bg_b        (vga_b_next),
                .out_r       (trail_overlay_r),
                .out_g       (trail_overlay_g),
                .out_b       (trail_overlay_b)
            );
        end else begin : gen_no_knife_trail
            assign trail_overlay_r = vga_r_next;
            assign trail_overlay_g = vga_g_next;
            assign trail_overlay_b = vga_b_next;
        end
    endgenerate

    knife_renderer knife_renderer_inst (
        .clk         (vga_clk),
        .reset       (reset),
        .knife_valid (ENABLE_KNIFE_SPRITE && ENABLE_PROP_TRACKER && knife_center_valid),
        .knife_x     (knife_center_x),
        .knife_y     (knife_center_y),
        .draw_x      (draw_x),
        .draw_y      (draw_y),
        .bg_r        (trail_overlay_r),
        .bg_g        (trail_overlay_g),
        .bg_b        (trail_overlay_b),
        .out_r       (knife_overlay_r),
        .out_g       (knife_overlay_g),
        .out_b       (knife_overlay_b)
    );

    assign VGA_R = knife_overlay_r;
    assign VGA_G = knife_overlay_g;
    assign VGA_B = knife_overlay_b;
endmodule

module sram_test_source (
    input  logic        clk,
    input  logic        reset,
    input  logic [1:0]  mode,
    output logic        fifo_valid,
    input  logic        fifo_ready,
    output logic [17:0] fifo_data
);

    logic [8:0]  x;
    logic [7:0]  y;
    logic        sof;
    logic [15:0] pixel;

    always_comb begin
        unique case (mode)
            2'b00: begin
                if (x < 9'd40) begin
                    pixel = 16'hf800;
                end else if (x < 9'd80) begin
                    pixel = 16'h07e0;
                end else if (x < 9'd120) begin
                    pixel = 16'h001f;
                end else if (x < 9'd160) begin
                    pixel = 16'hffe0;
                end else if (x < 9'd200) begin
                    pixel = 16'h07ff;
                end else if (x < 9'd240) begin
                    pixel = 16'hf81f;
                end else if (x < 9'd280) begin
                    pixel = 16'hffff;
                end else begin
                    pixel = 16'h0000;
                end
            end

            2'b01: begin
                pixel = {x[8:4], y[7:2], x[7:3]};
            end

            2'b10: begin
                pixel = x[4] ^ y[4] ? 16'hffff : 16'h0000;
            end

            default: begin
                pixel = {x[7:3], x[5:0], y[7:3]};
            end
        endcase
    end

    assign fifo_valid = 1'b1;
    assign fifo_data = {sof, 1'b0, pixel};

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x <= 9'd0;
            y <= 8'd0;
            sof <= 1'b1;
        end else if (fifo_ready) begin
            sof <= 1'b0;

            if (x == 9'd319) begin
                x <= 9'd0;
                if (y == 8'd239) begin
                    y <= 8'd0;
                    sof <= 1'b1;
                end else begin
                    y <= y + 1'b1;
                end
            end else begin
                x <= x + 1'b1;
            end
        end
    end
endmodule

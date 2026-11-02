// SC500CS RAW10 -> ISP -> DDR2 -> HDMI; recognition runs in the display domain.
// SW1 (A4): count audit; SW2 (B4): detection. Active-low board inputs.
//   KEY1~4 / SW1~4 -> alg_ctrl(100MHz) -+-> CDC -> 摄像头域: alg_engine_96 / target_detect_96
//                                       +-> CDC -> HDMI 域 : video_overlay / osd_engine
//   整帧亮度统计 (摄像头域) -> CDC -> auto_exposure(24MHz) -> I2C 写摄像头增益/曝光
//   手术器械包围盒 (摄像头域) -> CDC -> HDMI 域 OSD 叠加

//   N2  (J1-22) : 目标存在指示, 高有效  -> 可接继电器/灯

module design_top_wrapper116 (
    input wire        I_sys_clk,
    input wire        I_rst_n,

    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,

    inout  wire [1:0] I_button,

    input  wire [3:0] I_key_n,          // KEY1~4, 低有效
    input  wire [3:0] I_sw,             // SW1..SW4, active low; I_sw[1] is SW2 (B4)
    output wire [3:0] O_led,

    output wire       O_screen_pwm,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n,
    inout wire        IO_rx_clk_pad_p,
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n
);

    wire        S_100m_clk;
    wire        S_24m_clk;
    wire        S_pll_lock;
    wire        S_rst_n;

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;

    wire        S_csi_rx_clk;

    assign S_rst_n       = S_pll_lock;
    assign S_hdmi_rst_n  = S_pll_lock;
    assign S_video_out_rst_n = S_hdmi_rst_n;

    assign O_cam_rst  = 1'b1;
    assign O_cam_24m  = S_24m_clk;
    assign O_screen_pwm = 1'b1;

    wire [15:0]  S_ae;
    wire [15:0]  S_ag;
    wire         S_cam_cfg_done;
    wire         S_ae_cfg_done;wire S_cfg_error;
    wire         S_ae_req;

    wire         S_frame_toggle;
    reg          S_fps_toggle_hdmi_ff1;
    reg          S_fps_toggle_hdmi_ff2;
    reg          S_fps_toggle_hdmi_d;
    wire         S_camera_frame_pulse_hdmi = S_fps_toggle_hdmi_ff2 ^ S_fps_toggle_hdmi_d;
    wire [31:0]  S_frame_sum;
    wire [31:0]  S_frame_cnt;
    (* keep *) wire [7:0] S_mean;
    (* keep *) wire S_mean_toggle;

    wire [7:0]   S_dig_mean;
    wire [7:0]   S_isp_mean_post;

    wire [7:0] S_meter_mean,S_meter_target;wire S_meter_valid,S_meter_toggle;
    wire S_allow_digital,S_allow_digital_cam;
    wire [47:0] S_light_bus,S_light_bus_hdmi;wire S_light_toggle;
    assign S_mean=S_meter_mean;assign S_mean_toggle=S_meter_toggle;
    auto_exposure81 u_auto_exposure(
      .I_clk(S_24m_clk),.I_rst_n(S_rst_n),.I_enable(1'b1),.I_cam_cfg_done(S_cam_cfg_done),.I_ae_cfg_done(S_ae_cfg_done),
      .I_meter_toggle(S_meter_toggle),.I_meter_valid(S_meter_valid),.I_meter_mean(S_meter_mean),.I_meter_target(S_meter_target),
      .O_ae_req(S_ae_req),.O_ae(S_ae),.O_ag(S_ag),.O_allow_digital(S_allow_digital));
    cdc_bit_sync digital_limit_sync(.I_dst_clk(S_csi_rx_clk),.I_dst_rst_n(S_rst_n),.I_d(S_allow_digital),.O_q(S_allow_digital_cam));
    cdc_bus_sync #(.W(48)) light_sync(.I_dst_clk(S_hdmi_pixel_clk),.I_dst_rst_n(S_hdmi_rst_n),
      .I_d(S_light_bus),.I_toggle(S_light_toggle),.O_q(S_light_bus_hdmi),.O_upd());

    uicfgcs500_720p78 #(
      .CLK_DIV(24000000 / 100000 - 1)
    ) u_uicfgcs500 (
      .I_clk        ( S_24m_clk      ),
      .I_rst_n      ( S_rst_n        ),
      .I_ae_req     ( S_ae_req       ),
      .I_ae         ( S_ae           ),
      .I_ag         ( S_ag           ),
      .O_cam_scl    ( O_cam_scl      ),
      .IO_cam_sda   ( IO_cam_sda     ),
      .O_cfg_done   ( S_cam_cfg_done ),
      .O_ae_cfg_done( S_ae_cfg_done  ),.O_cfg_error(S_cfg_error)
    );

// 人机控制单元 (100MHz) + 控制字跨时钟域

    wire [47:0] S_ctrl_bus_100m;
    wire        S_ctrl_tog_100m;

    wire [2:0]  S_ctrl_mode;
    wire [3:0]  S_ctrl_param;
    wire [7:0]  S_ctrl_th_bin;
    wire [7:0]  S_ctrl_th_edge;
    wire [1:0]  S_ctrl_strength;
    wire [7:0]  S_ctrl_th_r;
    wire [7:0]  S_ctrl_th_d;
    wire        S_ctrl_osd_en;
    wire        S_ctrl_detect_en;
    wire        S_ctrl_debug_raw;

    alg_ctrl111 u_alg_ctrl (
        .I_clk       ( S_100m_clk      ),
        .I_rst_n     ( S_rst_n         ),
        .I_key_n     ( I_key_n         ),
        .I_sw        ( I_sw            ),
        .O_mode      (                 ),
        .O_param     (                 ),
        .O_th_bin    (                 ),
        .O_th_edge   (                 ),
        .O_strength  (                 ),
        .O_th_r      (                 ),
        .O_th_d      (                 ),
        .O_osd_en    (                 ),
        .O_detect_en (                 ),
        .O_dilation_en(                 ),
        .O_debug_raw  (                 ),
        .O_ctrl_bus  ( S_ctrl_bus_100m ),
        .O_ctrl_toggle(S_ctrl_tog_100m )
    );

    wire [47:0] S_ctrl_bus_cam;
    wire        S_ctrl_tog_cam;

    cdc_bus_sync #(.W(48)) u_ctrl_sync_cam (
        .I_dst_clk   ( S_csi_rx_clk    ),
        .I_dst_rst_n ( S_rst_n         ),
        .I_d        ( S_ctrl_bus_100m  ),
        .I_toggle   ( S_ctrl_tog_100m  ),
        .O_q        ( S_ctrl_bus_cam   ),
        .O_upd      ( S_ctrl_tog_cam   )
    );

    assign S_ctrl_mode       = S_ctrl_bus_cam[2:0];
    assign S_ctrl_param      = S_ctrl_bus_cam[6:3];
    assign S_ctrl_th_bin     = S_ctrl_bus_cam[14:7];
    assign S_ctrl_th_edge    = S_ctrl_bus_cam[22:15];
    assign S_ctrl_strength   = S_ctrl_bus_cam[24:23];
    assign S_ctrl_osd_en     = S_ctrl_bus_cam[25];
    assign S_ctrl_detect_en  = S_ctrl_bus_cam[26];
    assign S_ctrl_th_r       = S_ctrl_bus_cam[34:27];
    assign S_ctrl_th_d       = S_ctrl_bus_cam[42:35];
    assign S_ctrl_debug_raw   = S_ctrl_bus_cam[44];

    wire [47:0] S_ctrl_bus_hdmi;

    cdc_bus_sync #(.W(48)) u_ctrl_sync_hdmi (
        .I_dst_clk   ( S_hdmi_pixel_clk ),
        .I_dst_rst_n ( S_hdmi_rst_n     ),
        .I_d        ( S_ctrl_bus_100m   ),
        .I_toggle   ( S_ctrl_tog_100m   ),
        .O_q        ( S_ctrl_bus_hdmi   ),
        .O_upd      (                   )
    );

    wire        S_hs_rx_valid;
    wire[15:0]  S_hs_rx_data;
    wire[1:0]   S_lane_error;

    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "0dB"   ),
        .HS_VGA_GAIN           ( "8dB"   ),
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),

        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),

        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),

        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),

        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),

        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );

    wire        S_csi_frame_start;
    wire        S_csi_frame_end;
    wire        S_csi_valid;
    wire[31:0]  S_csi_data;

    wire        S_raw10_frame_start;
    wire        S_raw10_frame_end;
    wire        S_raw10_valid;
    wire [39:0] S_raw10_data;

    wire        S_axis_tlast;
    wire        S_axis_tuser;
    wire [39:0] S_axis_tdata;
    wire        S_axis_tvalid;

    csi_unpacket_2lane u_csi_unpacket(
        .I_clk            ( S_csi_rx_clk       ),
        .I_rst_n          ( S_rst_n            ),
        .I_hs_valid       ( S_hs_rx_valid      ),
        .I_hs_data        ( S_hs_rx_data       ),
        .O_csi_frame_start( S_csi_frame_start  ),
        .O_csi_frame_end  ( S_csi_frame_end    ),
        .O_csi_valid      ( S_csi_valid        ),
        .O_csi_data       ( S_csi_data         )
    );

    raw10_unpacket_2lane u_raw10_unpacket (
        .I_clk              ( S_csi_rx_clk        ),
        .I_rst_n            ( S_rst_n             ),
        .I_csi_frame_start  ( S_csi_frame_start   ),
        .I_csi_frame_end    ( S_csi_frame_end     ),
        .I_csi_valid        ( S_csi_valid         ),
        .I_csi_data         ( S_csi_data          ),
        .O_raw10_frame_start( S_raw10_frame_start ),
        .O_raw10_frame_end  ( S_raw10_frame_end   ),
        .O_raw10_valid      ( S_raw10_valid       ),
        .O_raw10_data       ( S_raw10_data        ),

        //   raw10_unpacket_2lane (the FIFO/BLC block there is commented out and

        .I_camera_black_level( 10'd0 )
    );

    uial2axis #(
        .IMG_WIDTH       (1280),
        .IMG_HEIGHT      (720 ),
        .INPUT_DATA_WIDTH(40  )
    )
    u_uial2axis (
        .I_native_clk ( S_csi_rx_clk        ),
        .I_rst_n      ( S_rst_n             ),
        .I_data       ( S_raw10_data        ),
        .I_data_valid ( S_raw10_valid       ),
        .I_data_start ( S_raw10_frame_start ),
        .I_data_end   ( S_raw10_frame_end   ),
        .axis_tvalid  ( S_axis_tvalid       ),
        .axis_tdata   ( S_axis_tdata        ),
        .axis_tuser   ( S_axis_tuser        ),
        .axis_tlast   ( S_axis_tlast        )
    );

    wire [127:0]  S_ISP_O_tdata;
    wire          S_ISP_O_tlast;
    wire          S_ISP_O_tuser;
    wire          S_ISP_O_tvalid;

    wire [10:0]   S_tgt_min_x;
    wire [10:0]   S_tgt_max_x;
    wire [9:0]    S_tgt_min_y;
    wire [9:0]    S_tgt_max_y;
    wire [10:0]   S_tgt_cx;
    wire [9:0]    S_tgt_cy;
    wire [31:0]   S_tgt_area;
    wire          S_tgt_valid;
    wire [7:0]    S_tool_count;
    wire          S_tool_alarm;
    wire [3:0]    S_global_valid;

    wire [43:0]   S_global_x0;
    wire [43:0]   S_global_x1;
    wire [39:0]   S_global_y0;
    wire [39:0]   S_global_y1;
    wire [127:0]  S_global_area;
    wire [7:0]    S_global_class;
    wire [31:0]   S_global_confidence;
     wire [7:0]  S_global_count;
     wire [7:0]  S_debug_mask_level;
     wire        S_debug_binary;
     wire [31:0] S_raw_cnt_area;
     wire [10:0] S_raw_x0;
     wire [10:0] S_raw_x1;
     wire [9:0]  S_raw_y0;
     wire [9:0]  S_raw_y1;
     wire        S_debug_object_valid;

     wire [31:0] S_mask_pixel_cnt;
     wire [31:0] S_closed_pixel_cnt;
     wire [31:0] S_valid_beat_cnt;

    isp_top109 #(

        .GREEN_MIN_DEF  (8'd32),
        .TH_RG_DEF      (8'd12),
        .TH_BG_DEF      (8'd12),
        .BRIGHT_MIN_DEF (8'd72),

        .MORPH_EN (0),
        .MORPH_CLOSE_EN (1),
        .DET_MIN_AREA   (120),
        .DET_MIN_SPAN   (4)
    ) u_isp_top (
        .axi4s_video_aclk ( S_csi_rx_clk     ),
        .I_allow_digital(S_allow_digital_cam),.O_light_bus(S_light_bus),.O_light_toggle(S_light_toggle),
        .O_meter_mean(S_meter_mean),.O_meter_target(S_meter_target),.O_meter_valid(S_meter_valid),.O_meter_toggle(S_meter_toggle),
        .I_rst_n          ( S_rst_n          ),
        .I_tlast          ( S_axis_tlast     ),
        .I_tuser          ( S_axis_tuser     ),
        .I_tdata          ( S_axis_tdata     ),
        .I_tvalid         ( S_axis_tvalid    ),
        .I_tdest          ( 10'd0            ),
        .O_tready         ( 1'b1             ),
        .O_tdata          ( S_ISP_O_tdata    ),
        .O_tlast          ( S_ISP_O_tlast    ),
        .O_tuser          ( S_ISP_O_tuser    ),
        .O_tvalid         ( S_ISP_O_tvalid   ),
        .I_tready         (                  ),

        .I_mode           ( 3'd0            ),
        .I_th_bin         ( S_ctrl_th_bin    ),
        .I_th_edge        ( S_ctrl_th_edge   ),
        .I_strength       ( S_ctrl_strength  ),
        .I_debug_raw      ( S_ctrl_debug_raw ),
        .I_th_r           ( S_ctrl_th_r      ),
        .I_th_d           ( S_ctrl_th_d      ),

        .O_frame_sum      ( S_frame_sum      ),
        .O_frame_cnt      ( S_frame_cnt      ),
        .O_frame_toggle   ( S_frame_toggle   ),
        .O_dig_mean       ( S_dig_mean       ),
        .O_dig_mean_post  ( S_isp_mean_post  ),

        .O_tgt_min_x      ( S_tgt_min_x      ),
        .O_tgt_max_x      ( S_tgt_max_x      ),
        .O_tgt_min_y      ( S_tgt_min_y      ),
        .O_tgt_max_y      ( S_tgt_max_y      ),
        .O_tgt_cx         ( S_tgt_cx         ),
        .O_tgt_cy         ( S_tgt_cy         ),
        .O_tgt_area       ( S_tgt_area       ),
        .O_tgt_valid      ( S_tgt_valid      ),
        .O_tool_count     ( S_tool_count     ),
        .O_tool_alarm     ( S_tool_alarm     ),
        .O_global_valid   ( S_global_valid   ),
        .O_global_x0      ( S_global_x0      ),
        .O_global_x1      ( S_global_x1      ),
        .O_global_y0      ( S_global_y0      ),
        .O_global_y1      ( S_global_y1      ),
        .O_global_area    ( S_global_area    ),
        .O_global_class   ( S_global_class   ),
        .O_global_confidence( S_global_confidence ),
        .O_global_count   ( S_global_count   ),
        .O_debug_binary   ( S_debug_binary    ),
        .O_debug_area     ( S_raw_cnt_area    ),
        .O_debug_x_min    ( S_raw_x0          ),
        .O_debug_x_max    ( S_raw_x1          ),
        .O_debug_y_min    ( S_raw_y0          ),
        .O_debug_y_max    ( S_raw_y1          ),
        .O_debug_object_valid( S_debug_object_valid ),
        .O_debug_mask_level ( S_debug_mask_level  ),
        .O_mask_pixel_cnt   ( S_mask_pixel_cnt    ),
        .O_closed_pixel_cnt ( S_closed_pixel_cnt  ),
        .O_valid_beat_cnt   ( S_valid_beat_cnt    )
    );

    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;
    wire[127:0] S_vi_128b_data;

    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy;
    wire[1:0]   S_video_out_rp;

    wire        S_ddr_user_wr_en;
    wire        S_ddr_user_rd_en;
    wire[24:0]  S_ddr_user_addr;
    wire[127:0] S_ddr_user_wr_data;
    wire        S_ddr_user_ready;
    wire        S_ddr_user_rd_valid;
    wire[127:0] S_ddr_user_rd_data;

    wire        S_vi_ddr_wr_en;
    wire[24:0]  S_vi_ddr_wr_addr;
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;
    wire[24:0]  S_vo_ddr_rd_addr;
    wire        S_vo_ddr_rd_ready;

    wire        S_init_calib_complete;
    wire[24:0]  S_mc_app_addr;
    wire[2:0]   S_mc_app_cmd;
    wire        S_mc_app_en;
    wire[127:0] S_mc_app_wdf_data;
    wire        S_mc_app_wdf_end;
    wire[15:0]  S_mc_app_wdf_mask;
    wire        S_mc_app_wdf_wren;
    wire[127:0] S_mc_app_rd_data;
    wire        S_mc_app_rd_data_end;
    wire        S_mc_app_rd_data_valid;
    wire        S_mc_app_rdy;
    wire        S_mc_app_wdf_rdy;
    wire        S_mc_app_rd_rdy;
    wire        S_mc_app_wr_rdy;

    wire [1:0] S_display_rp,S_pending_rp;
    wire S_pending_valid;
    wire S_display_valid,S_frame_ready;
    wire S_tag_ingress,S_tag_write,S_tag_commit,S_tag_display,S_tag_display_valid;
    wire [1:0] S_tag_write_slot,S_tag_commit_slot,S_tag_display_slot;
    wire [15:0] S_video_latency_ms,S_latency_frame,S_latency_repeat,S_latency_skip;
    wire [23:0] S_latency_now_ms;wire S_video_latency_valid,S_latency_fault;
    wire [7:0] S_rx_drop_gray;wire S_ingress_fault;
    (* ASYNC_REG="TRUE" *) reg [1:0] S_capture_enable;
    always @(posedge S_csi_rx_clk or negedge S_rst_n)begin
      if(!S_rst_n)S_capture_enable<=0;
      else S_capture_enable<={S_capture_enable[0],S_init_calib_complete&&S_cam_cfg_done};
    end
    video_in78 u_video_in(
        .O_ingress_sof(S_tag_ingress),.O_write_sof(S_tag_write),.O_write_commit(S_tag_commit),
        .O_write_slot(S_tag_write_slot),.O_commit_slot(S_tag_commit_slot),
        .I_rst_n             ( S_rst_n          ),
        .I_camera_clk        ( S_csi_rx_clk     ),
        .I_camera_frame_start( S_ISP_O_tuser    ),
        .I_camera_valid      ( S_ISP_O_tvalid   ),
        .I_camera_data       ( S_ISP_O_tdata    ),.I_capture_enable(S_capture_enable[1]),
        .O_drop_gray(S_rx_drop_gray),.O_ingress_fault(S_ingress_fault),
        .I_mipi_rx_error     ( 1'b0             ),
        .I_ddr_clk           ( S_ddr_clk        ),
        .I_display_pause     ( 1'b0             ),
        .I_video_out_rd_busy ( S_video_out_rd_busy ),
        .O_video_in_wr_busy  ( S_video_in_wr_busy  ),
        .O_video_out_rp      ( S_video_out_rp   ),
        .I_pending_rp(S_pending_rp),.I_pending_valid(S_pending_valid),
        .I_display_rp(S_display_rp),.I_display_valid(S_display_valid),.O_frame_ready(S_frame_ready),
        .O_ddr_user_wr_en    ( S_vi_ddr_wr_en   ),
        .O_ddr_user_addr     ( S_vi_ddr_wr_addr ),
        .O_ddr_user_wr_data  ( S_vi_ddr_wr_data ),
        .I_ddr_user_ready    ( S_ddr_user_ready )
    );

    assign S_ddr_user_wr_en   = S_vi_ddr_wr_en;
    assign S_ddr_user_rd_en   = S_vo_ddr_rd_en;
    assign S_ddr_user_addr    = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 25'd0;
    assign S_ddr_user_wr_data = S_vi_ddr_wr_data;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire [23:0] S_video_rd_data;

    assign S_video_out_vsync = ~S_hdmi_vsync;

    wire [3:0] S_vo_und_cnt;
    wire [3:0] S_vo_stall_cnt;

    video_out77 u_video_out(
        .O_display_commit(S_tag_display),.O_display_slot(S_tag_display_slot),.O_display_valid(S_tag_display_valid),
        .I_rst_n             ( S_video_out_rst_n ),
        .I_ddr_clk           ( S_ddr_clk         ),
        .O_video_out_rd_busy ( S_video_out_rd_busy ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy  ),
        .I_video_out_rp      ( S_video_out_rp    ),
        .O_pending_rp(S_pending_rp),.O_pending_valid(S_pending_valid),
        .I_frame_ready(S_frame_ready),.O_active_rp(S_display_rp),.O_active_valid(S_display_valid),
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en    ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr  ),
        .I_ddr_user_ready    ( S_ddr_user_ready  ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data  ),
        .I_dsi_clk           ( S_hdmi_pixel_clk  ),
        .I_video_vsync       ( S_video_out_vsync ),
        .I_video_rd_en       ( S_hdmi_window_rd_en ),
        .O_vdieo_data        ( S_video_rd_data   ),
        .O_und_cnt           ( S_vo_und_cnt      ),
        .O_stall_cnt         ( S_vo_stall_cnt    )
    );

    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk           ),
        .I_rst_n                 ( S_rst_n             ),
        .I_ddr_user_wr_en        ( S_ddr_user_wr_en    ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en    ),
        .I_ddr_user_addr         ( S_ddr_user_addr     ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data  ),
        .O_ddr_user_ready        ( S_ddr_user_ready    ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data  ),
        .O_mc_app_en             ( S_mc_app_en         ),
        .O_mc_app_addr           ( S_mc_app_addr       ),
        .O_mc_app_cmd            ( S_mc_app_cmd        ),
        .I_mc_app_rdy            ( S_mc_app_rdy        ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren   ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data   ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end    ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask   ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy    ),
        .I_mc_app_rd_rdy         ( S_mc_app_rd_rdy     ),
        .I_mc_app_wr_rdy         ( S_mc_app_wr_rdy     ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data    ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end  ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid)
    );

    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),
        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),
        .O_mc_app_rd_rdy        ( S_mc_app_rd_rdy        ),
        .O_mc_app_wr_rdy        ( S_mc_app_wr_rdy        ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );

    uivtc #(
        .H_ActiveSize ( 1280 ),
        .H_FrameSize  ( 1650 ),
        .H_SyncStart  ( 1390 ),
        .H_SyncEnd    ( 1430 ),
        .V_ActiveSize ( 720  ),
        .V_FrameSize  ( 750  ),
        .V_SyncStart  ( 725  ),
        .V_SyncEnd    ( 730  )
    )u_hdmi_vtc(
        .I_vtc_rstn    ( S_hdmi_rst_n     ),
        .I_vtc_clk     ( S_hdmi_pixel_clk ),
        .O_vtc_vs      ( S_hdmi_vsync     ),
        .O_vtc_hs      ( S_hdmi_hsync     ),
        .O_vtc_de_valid( S_hdmi_de        ),
        .O_vtc_user    ( S_hdmi_user      ),
        .O_vtc_last    ( S_hdmi_last      )
    );

    wire [95:0] S_tgt_bus_cam;
    wire [95:0] S_tgt_bus_hdmi;
    wire [171:0] S_global_bbox_bus_cam;
    wire [171:0] S_global_bbox_bus_hdmi;

    wire [7:0]   S_global_cls_cam   = S_global_class;
    wire [7:0]   S_global_cls_hdmi;

    //   高位纯属浪费 CDC 触发器 (128bit 总线 = 128 个 2FF + 128bit 比较器)。

    wire [95:0]  S_global_area_cam;
    slot_area_pack u_area_pack (
        .I_area32 ( S_global_area  ),
        .O_area24 ( S_global_area_cam )
    );
    wire [95:0]  S_global_area_hdmi;

    wire        S_slot3_v  = S_global_valid[3];
    wire [10:0] S_slot3_x0 = S_global_x0[43:33];
    wire [10:0] S_slot3_x1 = S_global_x1[43:33];
    wire [9:0]  S_slot3_y0 = S_global_y0[39:30];
    wire [9:0]  S_slot3_y1 = S_global_y1[39:30];

    assign S_global_bbox_bus_cam = {
        S_slot3_x0,         S_slot3_x1,         S_slot3_y0,         S_slot3_y1,         S_slot3_v,
        S_global_x0[32:22], S_global_x1[32:22], S_global_y0[29:20], S_global_y1[29:20], S_global_valid[2],
        S_global_x0[21:11], S_global_x1[21:11], S_global_y0[19:10], S_global_y1[19:10], S_global_valid[1],
        S_global_x0[10:0],  S_global_x1[10:0],  S_global_y0[9:0],   S_global_y1[9:0],   S_global_valid[0]
    };

    assign S_tgt_bus_cam = { S_tgt_min_x, S_tgt_max_x, S_tgt_min_y, S_tgt_max_y,
                             S_tgt_cx,    S_tgt_cy,    S_tgt_area,  S_tgt_valid };

    cdc_bus_sync #(.W(96)) u_tgt_sync_hdmi (
        .I_dst_clk   ( S_hdmi_pixel_clk ),
        .I_dst_rst_n ( S_hdmi_rst_n     ),
        .I_d        ( S_tgt_bus_cam     ),
        .I_toggle   ( S_frame_toggle    ),
        .O_q        ( S_tgt_bus_hdmi    ),
        .O_upd      (                   )
    );

    cdc_bus_sync #(.W(172)) u_global_bbox_sync_hdmi (
        .I_dst_clk   ( S_hdmi_pixel_clk ),
        .I_dst_rst_n ( S_hdmi_rst_n     ),
        .I_d        ( S_global_bbox_bus_cam ),
        .I_toggle   ( S_frame_toggle    ),
        .O_q        ( S_global_bbox_bus_hdmi ),
        .O_upd      (                   )
    );

    cdc_bus_sync #(.W(8)) u_global_cls_sync_hdmi (
        .I_dst_clk ( S_hdmi_pixel_clk ),
        .I_dst_rst_n ( S_hdmi_rst_n     ),
        .I_d        ( S_global_cls_cam   ),
        .I_toggle   ( S_frame_toggle    ),
        .O_q        ( S_global_cls_hdmi  ),
        .O_upd      (                   )
    );

    cdc_bus_sync #(.W(96)) u_global_area_sync_hdmi (
        .I_dst_clk ( S_hdmi_pixel_clk ),
        .I_dst_rst_n ( S_hdmi_rst_n     ),
        .I_d        ( S_global_area_cam  ),
        .I_toggle   ( S_frame_toggle    ),
        .O_q        ( S_global_area_hdmi ),
        .O_upd      (                   )
    );

    // 摄像头帧 toggle -> HDMI 域同步；该观察路径不连接视频像素控制。
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_fps_toggle_hdmi_ff1 <= 1'b0;
            S_fps_toggle_hdmi_ff2 <= 1'b0;
            S_fps_toggle_hdmi_d   <= 1'b0;
        end else begin
            S_fps_toggle_hdmi_ff1 <= S_frame_toggle;
            S_fps_toggle_hdmi_ff2 <= S_fps_toggle_hdmi_ff1;
            S_fps_toggle_hdmi_d   <= S_fps_toggle_hdmi_ff2;
        end
    end

    wire [7:0] S_mean_hdmi;

    cdc_bus_sync #(.W(8)) u_mean_sync_hdmi (
        .I_dst_clk   ( S_hdmi_pixel_clk ),
        .I_dst_rst_n ( S_hdmi_rst_n     ),
        .I_d        ( S_isp_mean_post   ),
        .I_toggle   ( S_frame_toggle    ),
        .O_q        ( S_mean_hdmi       ),
        .O_upd      (                   )
    );

    // 摄像头域 -> HDMI 像素域：剪刀状态为帧级慢变化信号，使用两级同步器。
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire [23:0] S_hdmi_out_data;
    wire        S_tgt_flag;
    wire        S_heartbeat;
    wire        S_audit_alarm;

    frame_latency77 latency_observer(.rst_n(S_rst_n),.cam_clk(S_csi_rx_clk),.ddr_clk(S_ddr_clk),.pix_clk(S_hdmi_pixel_clk),
      .raw_sof(S_csi_frame_start),.ingress_sof(S_tag_ingress),.write_sof(S_tag_write),.write_slot(S_tag_write_slot),
      .write_commit(S_tag_commit),.commit_slot(S_tag_commit_slot),
      .display_commit(S_tag_display),.display_slot(S_tag_display_slot),.display_valid(S_tag_display_valid),
      .out_vs(S_hdmi_out_vsync),.out_de(S_hdmi_out_de),.video_ms(S_video_latency_ms),.frame_id(S_latency_frame),
      .repeat_frames(S_latency_repeat),.skip_frames(S_latency_skip),.video_valid(S_video_latency_valid),.fault(S_latency_fault),.now_ms(S_latency_now_ms));
    (* ASYNC_REG="TRUE" *) reg [7:0] rxg1,rxg2;
    (* ASYNC_REG="TRUE" *) reg [1:0] cfg1,cfg2;
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n)begin
      if(!S_hdmi_rst_n)begin rxg1<=0;rxg2<=0;cfg1<=0;cfg2<=0;end
      else begin rxg1<=S_rx_drop_gray;rxg2<=rxg1;cfg1<={S_cfg_error,S_cam_cfg_done};cfg2<=cfg1;end
    end
    wire [7:0] S_rx_drops;genvar rxbit;
    generate for(rxbit=0;rxbit<8;rxbit=rxbit+1)begin:rx_count_decode
      assign S_rx_drops[rxbit]=^rxg2[7:rxbit];
    end endgenerate
    video_overlay116 #(
        .IMG_WIDTH ( 1280 ),
        .IMG_HEIGHT( 720  ),

        .TAIL_FILL_PIXELS( 0 )
    ) u_video_overlay (
        .I_clk           ( S_hdmi_pixel_clk        ),
        .I_rst_n         ( S_hdmi_rst_n            ),

        .I_video_vsync   ( S_hdmi_vsync            ),
        .I_video_hsync   ( S_hdmi_hsync            ),
        .I_video_de      ( S_hdmi_de               ),
        .I_video_user    ( S_hdmi_user             ),
        .I_video_last    ( S_hdmi_last             ),
        .O_video_rd_en   ( S_hdmi_window_rd_en     ),
        .I_video_rd_data ( S_video_rd_data         ),
        .I_camera_frame_pulse ( S_camera_frame_pulse_hdmi ),
        .I_rx_drops(S_rx_drops),.I_cfg_done(cfg2[0]),.I_cfg_error(cfg2[1]),
        .I_latency_now_ms(S_latency_now_ms),.I_video_ms(S_video_latency_ms),.I_video_frame(S_latency_frame),
        .I_repeat_frames(S_latency_repeat),.I_skip_frames(S_latency_skip),.I_video_latency_valid(S_video_latency_valid),.I_latency_fault(S_latency_fault),

        .I_ctrl_mode     ( S_ctrl_bus_hdmi[2:0]    ),
        .I_audit_request ( S_ctrl_bus_hdmi[45]     ),
        .I_baseline_request(S_ctrl_bus_hdmi[46]),
        .I_audit_enable(S_ctrl_bus_hdmi[47]),
        .I_light_gain_r(S_light_bus_hdmi[44:33]),.I_light_gain_b(S_light_bus_hdmi[32:21]),.I_light_state(S_light_bus_hdmi[20:19]),.I_light_mean(S_light_bus_hdmi[7:0]),
        .O_alarm         ( S_audit_alarm           ),
        .I_ctrl_param    ( S_ctrl_bus_hdmi[6:3]    ),
        .I_ctrl_osd_en   ( S_ctrl_bus_hdmi[25]     ),
        .I_ctrl_detect_en( S_ctrl_bus_hdmi[26]     ),
        .I_ctrl_th_bin   ( S_ctrl_bus_hdmi[14:7]   ),
        .I_ctrl_th_edge  ( S_ctrl_bus_hdmi[22:15]  ),
        .I_ctrl_strength ( S_ctrl_bus_hdmi[24:23]  ),

        .I_stat_valid    ( S_tgt_bus_hdmi[0]       ),
        .I_mean          ( S_mean_hdmi             ),
        .I_tgt_cx        ( S_tgt_bus_hdmi[53:43]   ),
        .I_tgt_cy        ( S_tgt_bus_hdmi[42:33]   ),
        .I_tgt_area      ( S_tgt_bus_hdmi[32:1]    ),
        .I_bbox_x0       ( S_tgt_bus_hdmi[95:85]   ),
        .I_bbox_x1       ( S_tgt_bus_hdmi[84:74]   ),
        .I_bbox_y0       ( S_tgt_bus_hdmi[73:64]   ),
        .I_bbox_y1       ( S_tgt_bus_hdmi[63:54]   ),
        .I_global_bbox_bus( S_global_bbox_bus_hdmi ),
        .I_global_cls    ( S_global_cls_hdmi    ),
        .I_global_area   ( S_global_area_hdmi   ),
        .I_und_cnt       ( S_vo_und_cnt         ),
        .I_stall_cnt     ( S_vo_stall_cnt       ),

        .O_hdmi_vsync    ( S_hdmi_out_vsync        ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync        ),
        .O_hdmi_de       ( S_hdmi_out_de           ),
        .O_hdmi_data     ( S_hdmi_out_data         ),

        .O_led           ( O_led                   ),
        .O_target_flag   ( S_tgt_flag              ),
        .O_heartbeat     ( S_heartbeat             )
    );

    assign I_button[0] = S_tgt_flag;
    assign I_button[1] = S_audit_alarm;

    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_hdmi_out_vsync  ),
        .I_video_in_de      ( S_hdmi_out_de     ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_hdmi_out_data   ),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );

    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset       ( ~I_rst_n          ),
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),
        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),
        .lock        ( S_pll_lock        )
    );

endmodule

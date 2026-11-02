// Camera-domain ISP: demosaic, neutral-pixel AWB, exposure metering, tone and packing.
// Six-class recognition is implemented by scene_detect116 in the display domain.
//    5. ready 握手链按下游->上游逐级上返连接。

module isp_top109 #(

    parameter [7:0] GREEN_MIN_DEF  = 8'd32,
    parameter [7:0] TH_RG_DEF      = 8'd12,
    parameter [7:0] TH_BG_DEF      = 8'd12,
    parameter [7:0] BRIGHT_MIN_DEF = 8'd72,

    parameter integer SKIN_EN        = 1,
    parameter [7:0]   SKIN_RG_MIN   = 8'd16,
    parameter [7:0]   SKIN_RB_MIN   = 8'd20,

    parameter integer MORPH_EN       = 0,
    parameter integer MORPH_CLOSE_EN = 1,

    parameter integer DET_MIN_AREA = 120,
    parameter integer DET_MIN_SPAN = 4,

    parameter integer SHAPE_EN    = 1,

    parameter integer MERGE_X_NEAR = 16

) (
    input           axi4s_video_aclk,
    input           I_rst_n         ,
    input wire I_allow_digital,
    output wire [47:0] O_light_bus,output reg O_light_toggle,
    output wire [7:0] O_meter_mean,O_meter_target,output wire O_meter_valid,O_meter_toggle,
    input           I_tlast         ,
    input           I_tuser         ,
    input [39:0]    I_tdata         ,
    input           I_tvalid        ,
    input [9:0]     I_tdest         ,
    input           O_tready        ,
    output [127:0]  O_tdata         ,
    output          O_tlast         ,
    output          O_tuser         ,
    output          O_tvalid        ,
    output          I_tready        ,

    // ---------------- 算法控制 (alg_ctrl -> CDC 后本时钟域) ----------------
    input [2:0]     I_mode          ,
    input [7:0]     I_th_bin        ,
    input [7:0]     I_th_edge       ,
    input [1:0]     I_strength      ,
    input           I_debug_raw     ,

    input [7:0]     I_th_r          ,
    input [7:0]     I_th_d          ,

    output [31:0]   O_frame_sum     ,
    output [31:0]   O_frame_cnt     ,
    output          O_frame_toggle  ,

    output [7:0]     O_dig_mean      ,
    output [7:0]     O_dig_mean_post ,

    output [10:0]   O_tgt_min_x     ,
    output [10:0]   O_tgt_max_x     ,
    output [9:0]    O_tgt_min_y     ,
    output [9:0]    O_tgt_max_y     ,
    output [10:0]   O_tgt_cx        ,
    output [9:0]    O_tgt_cy        ,
    output [31:0]   O_tgt_area      ,
    output          O_tgt_valid,
    output [7:0]    O_tool_count,
    output          O_tool_alarm,

    output [3:0]    O_global_valid,
    output [43:0]   O_global_x0,
    output [43:0]   O_global_x1,
    output [39:0]   O_global_y0,
    output [39:0]   O_global_y1,
    output [127:0]  O_global_area,
    output [7:0]    O_global_class,
    output [31:0]   O_global_confidence,
    output [7:0]    O_global_count,

    output [31:0]   O_mask_pixel_cnt,
    output [31:0]   O_closed_pixel_cnt,
    output [31:0]   O_valid_beat_cnt,
    output [7:0]    O_debug_mask_level,
    output          O_debug_binary,
    output [31:0]   O_debug_area,
    output [10:0]   O_debug_x_min,
    output [10:0]   O_debug_x_max,
    output [9:0]    O_debug_y_min,
    output [9:0]    O_debug_y_max,
    output          O_debug_object_valid
);

    wire         m_aixs_tvalid;  //synthesis keep
    wire [127:0] m_aixs_tdata;   //synthesis keep
    wire         m_aixs_tuser;   //synthesis keep
    wire         m_aixs_tlast;   //synthesis keep
    wire         m_aixs_tready;  //synthesis keep

    wire [ 95:0] m_aixs_tdata_96; //synthesis keep

    wire wb_stable;wire [11:0] wb_r,wb_b;
    wire         awb_O_tlast;    //synthesis keep
    wire         awb_O_tuser;    //synthesis keep
    wire [ 95:0] awb_O_tdata;    //synthesis keep
    wire         awb_O_tvalid;   //synthesis keep
    wire         awb_O_tready;   //synthesis keep

    wire         alg_O_tlast;    //synthesis keep
    wire         alg_O_tuser;    //synthesis keep
    wire [ 95:0] alg_O_tdata;    //synthesis keep
    wire         alg_O_tvalid;   //synthesis keep

    wire         ce_O_tlast;      //synthesis keep
    wire         ce_O_tuser;      //synthesis keep
    wire [ 95:0] ce_O_tdata;      //synthesis keep
    wire         ce_O_tvalid;     //synthesis keep

    wire         gm_O_tlast;      //synthesis keep
    wire         gm_O_tuser;      //synthesis keep
    wire [ 95:0] gm_O_tdata;      //synthesis keep
    wire         gm_O_tvalid;     //synthesis keep
    wire         gm_I_ready;      //synthesis keep

    wire         d2_O_tuser_128; //synthesis keep
    wire         d2_O_tvalid_128;//synthesis keep
    wire [127:0] d2_O_tdata_128; //synthesis keep

    // ready 握手链 (下游 -> 上游逐级上返)

    wire ce_I_ready;
    wire alg_O_ready;

    wire [31:0] W_frame_sum;
    wire [31:0] W_frame_cnt;
    wire        W_frame_toggle;

    assign O_frame_sum    = W_frame_sum;
    assign O_frame_cnt    = W_frame_cnt;
    assign O_frame_toggle = W_frame_toggle;

    assign awb_O_tready = alg_O_ready;

wire [95:0] selected_rgb;
wire selected_user,selected_valid,selected_last;
isp_output_select109 compare_select(.clk(axi4s_video_aclk),.rst_n(I_rst_n),
 .request_raw(I_debug_raw),.raw_rgb(m_aixs_tdata_96),.raw_user(m_aixs_tuser),
 .raw_valid(m_aixs_tvalid),.raw_last(m_aixs_tlast),
 .processed_rgb(gm_O_tdata),.processed_user(gm_O_tuser),
 .processed_valid(gm_O_tvalid),.processed_last(gm_O_tlast),
 .rgb(selected_rgb),.sof(selected_user),.valid(selected_valid),.last(selected_last));
reg S_gm_tlast_d1;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
    if(!I_rst_n) S_gm_tlast_d1 <= 1'b0;
    else         S_gm_tlast_d1 <= selected_last;
end

assign O_tdata  = d2_O_tdata_128;
assign O_tvalid = d2_O_tvalid_128;
assign O_tuser  = d2_O_tuser_128;
assign O_tlast  = d2_O_tvalid_128 & S_gm_tlast_d1;

demosaic #(
    .IMG_HEIGHT          (720 ),
    .IMG_WIDTH           (1280),
    .data_complete_delay (50  ),
    .BAYER_MODE          ("BGGR")
)
u_demosaic
(
    .I_clk   			(axi4s_video_aclk)	,
    .I_rst_n 			(I_rst_n)	,
    .axi4s_video_tdata 	(I_tdata)	,
    .axi4s_video_tdest 	(I_tdest)	,
    .axi4s_video_tlast 	(I_tlast)	,
    .axi4s_video_tvalid	(I_tvalid)	,
    .axi4s_video_tuser 	(I_tuser)	,
    .axi4s_video_tready	(I_tready)	,
    .O_tlast  			(m_aixs_tlast)	,
    .O_tuser  			(m_aixs_tuser)	,
    .O_tdata  			(m_aixs_tdata)	,
    .O_tvalid 			(m_aixs_tvalid)	,
    .O_tready   		(m_aixs_tready)
);

data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

awb82 #(
    .IMG_HEIGHT(720 ),
    .IMG_WIDTH (1280)
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_meter_mean(O_meter_mean),.O_meter_target(O_meter_target),.O_meter_valid(O_meter_valid),.O_meter_toggle(O_meter_toggle),
    .O_wb_stable(wb_stable),.gain_r(wb_r),.gain_b(wb_b),
    .O_tready(awb_O_tready)
);

wire [7:0] S_green_min, S_th_rg, S_th_bg, S_bright_min;

alg_engine_96 #(
    .IMG_WIDTH (1280),
    .IMG_HEIGHT(720 )
) u_alg_engine_96 (
    .I_clk       (axi4s_video_aclk),
    .I_rst_n     (I_rst_n         ),
    .I_tlast     (awb_O_tlast     ),
    .I_tuser     (awb_O_tuser     ),
    .I_tdata     (awb_O_tdata     ),
    .I_tvalid    (awb_O_tvalid    ),
    .I_tready    (ce_I_ready      ),
    .I_mode      (I_mode          ),
    .I_th_bin    (I_th_bin        ),
    .I_th_edge   (I_th_edge       ),
    .I_strength  (I_strength      ),

    .I_green_min (S_green_min     ),
    .I_th_rg     (S_th_rg         ),
    .I_th_bg     (S_th_bg         ),
    .I_bright_min(S_bright_min    ),
    .O_tlast     (alg_O_tlast     ),
    .O_tuser     (alg_O_tuser     ),
    .O_tdata     (alg_O_tdata     ),
    .O_tvalid    (alg_O_tvalid    ),
    .O_tready    (alg_O_ready     ),
    .O_frame_sum (W_frame_sum     ),
    .O_frame_cnt (W_frame_cnt     ),
    .O_frame_toggle(W_frame_toggle)
);

wire [10:0] S_dig_gain;
wire [7:0] S_dig_mean;
(* keep *) wire [7:0] S_dig_mean_post;
(* keep *) wire [7:0] S_dig_mean_post_r;

wire [1:0] light_state;
auto_brightness81 u_auto_brightness(
 .clk(axi4s_video_aclk),.rst_n(I_rst_n),.sof(alg_O_tuser),
 .meter_toggle(O_meter_toggle),.meter_valid(O_meter_valid),.allow_digital(I_allow_digital),.wb_stable(wb_stable),
 .meter_mean(O_meter_mean),.meter_target(O_meter_target),.gain(S_dig_gain),.light_state(light_state));
assign S_dig_mean=O_meter_mean;
assign S_dig_mean_post=O_meter_mean;assign S_dig_mean_post_r=O_meter_mean;
reg [47:0] light_packet;
assign O_light_bus=light_packet;
always @(posedge axi4s_video_aclk or negedge I_rst_n)begin
 if(!I_rst_n)begin light_packet<={3'd0,12'd256,12'd256,2'd3,11'd256,8'd0};O_light_toggle<=0;end
 else if(alg_O_tuser)begin light_packet<={3'd0,wb_r,wb_b,light_state,S_dig_gain,O_meter_mean};O_light_toggle<=~O_light_toggle;end
end

assign O_dig_mean      = S_dig_mean;
assign O_dig_mean_post = S_dig_mean_post_r;

wire [3:0]  S_tool_mask;
wire        S_seg_tuser, S_seg_tvalid;
wire [31:0] S_mask_pixel_cnt, S_valid_beat_cnt;

assign O_mask_pixel_cnt = S_mask_pixel_cnt;
assign O_valid_beat_cnt = S_valid_beat_cnt;

green_background_segment_96 #(
    .GREEN_MIN_DEF (GREEN_MIN_DEF ),
    .TH_RG_DEF     (TH_RG_DEF     ),
    .TH_BG_DEF     (TH_BG_DEF     ),
    .BRIGHT_MIN_DEF(BRIGHT_MIN_DEF),
    .SKIN_EN      (SKIN_EN      ),
    .SKIN_RG_MIN  (SKIN_RG_MIN  ),
    .SKIN_RB_MIN  (SKIN_RB_MIN  )
) u_green_background_segment_96 (
    .I_clk       (axi4s_video_aclk),
    .I_rst_n     (I_rst_n         ),
    .I_tuser     (awb_O_tuser     ),
    .I_tvalid    (awb_O_tvalid    ),
    .I_tdata     (awb_O_tdata     ),
    .I_green_min (I_th_r          ),
    .I_th_rg     (I_th_d          ),
    .I_th_bg     (I_th_d          ),
    .I_bright_min(BRIGHT_MIN_DEF  ),
    .O_tuser     (S_seg_tuser     ),
    .O_tvalid    (S_seg_tvalid    ),
    .O_mask      (S_tool_mask     ),
    .O_mask_cnt  (S_mask_pixel_cnt),
    .O_valid_cnt (S_valid_beat_cnt),

    .O_green_min (S_green_min     ),
    .O_th_rg     (S_th_rg         ),
    .O_th_bg     (S_th_bg         ),
    .O_bright_min(S_bright_min    )
);

wire [95:0] S_close_tdata;
wire        S_close_tuser, S_close_tvalid;

mask_close_3x3_96 #(
    .IMG_WIDTH (1280), .IMG_HEIGHT(720),
    .MORPH_EN  (MORPH_EN      ),
    .CLOSE_EN  (MORPH_CLOSE_EN)
) u_mask_close_3x3_96 (
    .I_clk  (axi4s_video_aclk),
    .I_rst_n(I_rst_n          ),
    .I_tuser(S_seg_tuser      ),
    .I_tvalid(S_seg_tvalid    ),
    .I_mask (S_tool_mask      ),
    .O_tuser(S_close_tuser    ),
    .O_tvalid(S_close_tvalid  ),
    .O_tdata(S_close_tdata    ),
    .O_closed_cnt(O_closed_pixel_cnt)
);

// owns six-class recognition; preserve the legacy CDC contract at zero.
assign O_global_valid       = 4'b0;
assign O_global_x0          = 44'b0;
assign O_global_x1          = 44'b0;
assign O_global_y0          = 40'b0;
assign O_global_y1          = 40'b0;
assign O_global_area        = 128'b0;
assign O_global_class       = 8'b0;
assign O_global_confidence  = 32'b0;
assign O_global_count       = 8'b0;
assign O_debug_mask_level   = 8'b0;
assign O_debug_binary       = 1'b0;
assign O_debug_area         = 32'b0;
assign O_debug_x_min        = 11'b0;
assign O_debug_x_max        = 11'b0;
assign O_debug_y_min        = 10'b0;
assign O_debug_y_max        = 10'b0;
assign O_debug_object_valid = 1'b0;

// slot0 保留给旧的单目标 OSD/CDC 接口 (最小修正, 不改顶层时序契约)。
assign O_tgt_min_x = O_global_x0[10:0];
assign O_tgt_max_x = O_global_x1[10:0];
assign O_tgt_min_y = O_global_y0[9:0];
assign O_tgt_max_y = O_global_y1[9:0];
assign O_tgt_cx = (O_tgt_min_x + O_tgt_max_x) >> 1;
assign O_tgt_cy = (O_tgt_min_y + O_tgt_max_y) >> 1;
assign O_tgt_area = O_global_area[31:0];
assign O_tgt_valid = O_global_valid[0];
assign O_tool_count = O_global_count;
assign O_tool_alarm = (O_global_count == 0);

color_enhance #(

    .R_GAIN   (10'd256        ),
    .G_GAIN   (10'd256        ),
    .B_GAIN   (10'd256        ),
    .SAT_C    (10'd448        ),
    .SAT_Y    (10'd192        ),
    .SAT_BIAS (12'd1920       ),
    .SAT_D    (10'd256        ),
    .HI_KNEE  (10'd192        )
) u_color_enhance (
    .I_clk    (axi4s_video_aclk),
    .I_rst_n  (I_rst_n         ),
    .I_tlast  (alg_O_tlast     ),
    .I_tuser  (alg_O_tuser     ),
    .I_tdata  (alg_O_tdata     ),
    .I_tvalid (alg_O_tvalid    ),
    .I_tready (ce_I_ready     ),
    .I_gain   (S_dig_gain     ),
    .O_tlast  (ce_O_tlast      ),
    .O_tuser  (ce_O_tuser      ),
    .O_tdata  (ce_O_tdata      ),
    .O_tvalid (ce_O_tvalid     ),
    .O_tready (gm_I_ready      )
);

gamma_correct u_gamma_correct (
    .I_clk    (axi4s_video_aclk),
    .I_rst_n  (I_rst_n         ),
    .I_tlast  (ce_O_tlast      ),
    .I_tuser  (ce_O_tuser      ),
    .I_tdata  (ce_O_tdata      ),
    .I_tvalid (ce_O_tvalid     ),
    .I_tready (gm_I_ready      ),
    .O_tlast  (gm_O_tlast      ),
    .O_tuser  (gm_O_tuser      ),
    .O_tdata  (gm_O_tdata      ),
    .O_tvalid (gm_O_tvalid     ),
    .O_tready (1'b1            )
);

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),

        .I_96b_frame_start  ( selected_user        ),
        .I_96b_valid        ( selected_valid       ),
        .I_96b_data         ( selected_rgb        ),

        .O_128b_frame_start ( d2_O_tuser_128   ),
        .O_128b_valid       ( d2_O_tvalid_128  ),
        .O_128b_data        ( d2_O_tdata_128   )
    );

endmodule

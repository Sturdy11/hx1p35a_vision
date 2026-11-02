// Display-domain recognition, tracking and frame-atomic OSD composition.
// Modes change only at vertical blanking. Focus/BCD/boxes publish as one packet.
module video_overlay116 #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720,

    parameter TAIL_FILL_PIXELS = 0
)(

    input  wire         I_clk,
    input  wire         I_rst_n,

    input  wire         I_video_vsync,
    input  wire         I_video_hsync,
    input  wire         I_video_de,
    input  wire         I_video_user,
    input  wire         I_video_last,
    input  wire         I_camera_frame_pulse,
    output wire         O_video_rd_en,
    input  wire [23:0]  I_video_rd_data,

    // ---------------- 控制字 (alg_ctrl 经 CDC) ----------------
    input  wire [2:0]   I_ctrl_mode,
    input wire I_audit_request,I_baseline_request,I_audit_enable,output wire O_alarm,
    input wire [11:0] I_light_gain_r,I_light_gain_b,input wire [1:0] I_light_state,input wire [7:0] I_light_mean,
    input wire [23:0] I_latency_now_ms,
    input wire [15:0] I_video_ms,I_video_frame,I_repeat_frames,I_skip_frames,
    input wire I_video_latency_valid,I_latency_fault,
    input wire [7:0] I_rx_drops,input wire I_cfg_done,I_cfg_error,
    input  wire [3:0]   I_ctrl_param,
    input  wire         I_ctrl_osd_en,
    input  wire         I_ctrl_detect_en,
    input  wire [7:0]   I_ctrl_th_bin,
    input  wire [7:0]   I_ctrl_th_edge,
    input  wire [1:0]   I_ctrl_strength,

    // ---------------- 统计 / 目标 (摄像头域经 CDC) ----------------
    input  wire         I_stat_valid,
    input  wire [7:0]   I_mean,
    input  wire [10:0]  I_tgt_cx,
    input  wire [9:0]   I_tgt_cy,
    input  wire [19:0]  I_tgt_area,
    input  wire [10:0]  I_bbox_x0,
    input  wire [10:0]  I_bbox_x1,
    input  wire [9:0]   I_bbox_y0,
    input  wire [9:0]   I_bbox_y1,

    input  wire [171:0] I_global_bbox_bus,

    input  wire [7:0]   I_global_cls,

    input  wire [95:0]  I_global_area,

    //     [3:0] U = 读侧 FIFO 欠载拍数(饱和15), [3:0] D = DDR 读突发停顿(饱和15)
    //     2FF 同步后送到 OSD 第三行, 不参与任何视频时序路径。
    input  wire [3:0]  I_und_cnt,
    input  wire [3:0]  I_stall_cnt,

    output wire         O_hdmi_vsync,
    output wire         O_hdmi_hsync,
    output wire         O_hdmi_de,
    output wire  [23:0]  O_hdmi_data,

    output reg  [3:0]   O_led,
    output wire         O_target_flag,
    output reg          O_heartbeat
);

    reg [3:0] stall_sync1,stall_sync2;
    always @(posedge I_clk or negedge I_rst_n) begin
      if(!I_rst_n) begin stall_sync1<=0;stall_sync2<=0;end
      else begin stall_sync1<=I_stall_cnt;stall_sync2<=stall_sync1;end
    end
    assign O_video_rd_en=I_video_de;
    reg [1:0] vd,hd,sd;
    reg [11:0] px,py;
    reg old_vs;
    reg [23:0] last_pixel;
    wire tail=(TAIL_FILL_PIXELS!=0)&&(px>=IMG_WIDTH-TAIL_FILL_PIXELS);
    wire [23:0] shown_pixel=tail?last_pixel:I_video_rd_data;
    wire [23:0] obj;
    wire [215:0] bx0,bx1;
    wire [191:0] by0,by1;
    wire [71:0] cls;wire [47:0] ring_ends;
    wire [41:0] counts;
    wire [3:0] flags;
    wire [15:0] seq;
    wire busy;
    wire [95:0] diagnostics;
    wire pixel_mask;
    wire [23:0] stable_obj;
    wire [215:0] stable_x0,stable_x1;wire [191:0] stable_y0,stable_y1;
    wire [15:0] stable_sequence;wire [23:0] held_tracks;
    wire [71:0] stable_cls;wire [41:0] stable_counts;wire track_busy;

    reg packet_active,packet_ready;reg [7:0] packet_timer;
    reg [15:0] packet_sequence;
    wire focus_auto,focus_moving;wire panel_focus_valid,focus_hold,focus_busy;wire [4:0] panel_focus_id;wire [11:0] focus_x,focus_y;
    wire blank_start=sd[1]&&!old_vs;
    wire packet_commit=packet_active&&packet_timer==180&&!focus_busy;
    wire tracker_hold=packet_active||(blank_start&&!track_busy);
    wire moving,motion_box;wire [11:0] mx0,mx1,my0,my1;wire [14:0] motion_hits;

    wire [23:0] enhanced_pixel;
    display_tone69 display_tone(.rgb(shown_pixel),.out_rgb(enhanced_pixel));
    reg [2:0] display_mode;
    reg overlay_enable;
    reg preview;reg [7:0] display_threshold,edge_threshold;
    always @(posedge I_clk or negedge I_rst_n) begin
      if(!I_rst_n) begin display_mode<=0;overlay_enable<=1;preview<=0;display_threshold<=64;edge_threshold<=8;end
      else if(sd[1]&&!old_vs) begin
        display_mode<=I_ctrl_mode;preview<=0;overlay_enable<=I_ctrl_osd_en&&(I_ctrl_mode!=3'd5);display_threshold<=I_ctrl_th_bin;edge_threshold<=I_ctrl_th_edge;
      end
    end
    wire [23:0] display_pixel;
    wire render_de,render_hs,render_vs,render_overlay;
    wire [11:0] render_x,render_y;wire [2:0] render_mode;
    display_modes111 #(.W(IMG_WIDTH),.H(IMG_HEIGHT)) modes(
      .clk(I_clk),.rst_n(I_rst_n),.de(vd[1]),.hs(hd[1]),.vs(sd[1]),
      .overlay_enable(overlay_enable),.x(px),.y(py),
      .original_rgb(shown_pixel),.enhanced_rgb(enhanced_pixel),.pixel_mask(pixel_mask),
      .mode(display_mode),.threshold(display_threshold),.edge_threshold(edge_threshold),
      .out_de(render_de),.out_hs(render_hs),.out_vs(render_vs),.out_overlay(render_overlay),
      .out_x(render_x),.out_y(render_y),.out_mode(render_mode),.rgb(display_pixel));
    wire detect_enable=I_ctrl_detect_en&&(display_mode!=3'd5);
    wire det_valid=vd[1] && detect_enable;

    always @(posedge I_clk or negedge I_rst_n) begin
      if(!I_rst_n) begin
        vd<=0; hd<=0; sd<=0; px<=0; py<=0; old_vs<=0;
        last_pixel<=0; O_heartbeat<=0; O_led<=0;
      end else begin
        vd<={vd[0],I_video_de}; hd<={hd[0],I_video_hsync};
        sd<={sd[0],I_video_vsync}; old_vs<=sd[1];
        if(sd[1]&&!old_vs) begin px<=0; py<=0; O_heartbeat<=~O_heartbeat; end
        else if(vd[1]) begin
          if(px==IMG_WIDTH-1) begin px<=0; py<=(py==IMG_HEIGHT-1)?0:py+1'b1; end
          else px<=px+1'b1;
          if(!tail) last_pixel<=I_video_rd_data;
        end
        O_led<={(|flags)|O_alarm,moving,(|stable_obj),O_heartbeat};
      end
    end

    scene_detect116 detector(
      .clk(I_clk),.rst_n(I_rst_n),.valid(det_valid),.enable(detect_enable),
      .x(px),.y(py),.rgb(tail?24'd0:I_video_rd_data),
      .objects(obj),.box_x0(bx0),.box_x1(bx1),.box_y0(by0),.box_y1(by1),
      .classes(cls),.ring_ends(ring_ends),.counts(counts),.status(flags),.sequence_id(seq),.busy(busy),
      .diagnostics(diagnostics),.pixel_mask(pixel_mask));

    // registered sequence/status pair is atomic and descriptors remain stable.
    wire [15:0] track_input_sequence;wire [3:0] track_input_status;
    scene_frame_guard88 frame_guard(.clk(I_clk),.rst_n(I_rst_n),.enable(detect_enable),
      .capture_start(vd[1]&&px==0&&py==0&&det_valid&&!busy),
      .tag_sample(vd[1]&&px==16&&py==0),.raw_sequence(seq),.raw_status(flags),
      .video_frame(I_video_frame),.now_ms(I_latency_now_ms[15:0]),.video_ms(I_video_ms),
      .stream_ok(I_video_latency_valid&&!I_latency_fault&&I_cfg_done&&!I_cfg_error),
      .result_sequence(track_input_sequence),.result_status(track_input_status));
    scene_stabilize110 stabilizer(.clk(I_clk),.rst_n(I_rst_n),
      .enable(detect_enable),.hold_updates(tracker_hold),
      .frame_tick(vd[1]&&px==0&&py==0),.sequence_id(track_input_sequence),.status(track_input_status),
      .in_ring_ends(ring_ends),.in_objects(obj),.in_x0(bx0),.in_x1(bx1),.in_y0(by0),.in_y1(by1),.in_classes(cls),
      .objects(stable_obj),.box_x0(stable_x0),.box_x1(stable_x1),.box_y0(stable_y0),.box_y1(stable_y1),
      .classes(stable_cls),.counts(stable_counts),.busy(track_busy),.held(held_tracks),.result_sequence(stable_sequence));

    wire frame_tick=vd[1]&&px==0&&py==0;
    wire [7:0] cam_rate,hdmi_rate,det_rate;
    frame_rates108 frame_rates(.clk(I_clk),.rst_n(I_rst_n),.now_ms(I_latency_now_ms[15:0]),
      .camera_tick(I_camera_frame_pulse),.display_tick(blank_start),.detect_enable(detect_enable),
      .result_sequence(track_input_sequence),.result_status(track_input_status),
      .rates({cam_rate,hdmi_rate,det_rate}));

    wire [2:0] motion_state;
    motion_grid105 motion(.clk(I_clk),.rst_n(I_rst_n),.enable(detect_enable),
      .frame_start(blank_start),.tag_sample(vd[1]&&px==16&&py==0),
      .stream_ok(I_video_latency_valid&&!I_latency_fault&&I_cfg_done&&!I_cfg_error),
      .source_frame(I_video_frame),.valid(vd[1]),.x(px),.y(py),.rgb(I_video_rd_data),
      .box_valid(motion_box),.x0(mx0),.x1(mx1),.y0(my0),.y1(my1),.hits(motion_hits),.state(motion_state));
    assign moving=motion_box;
    wire [35:0] baseline,missing_amount;wire [5:0] missing;wire [2:0] audit_state;
    wire source_observation,source_valid;wire [15:0] source_id,source_stamp;wire [3:0] source_status;
    reg [41:0] audit_counts;
    always @(posedge I_clk or negedge I_rst_n)begin
      if(!I_rst_n)audit_counts<=0;else if(packet_commit)audit_counts<=stable_counts;
    end

    wire source_ok=((I_light_state==2'd1)||(I_light_state==2'd2&&I_light_mean>=8'd48))&&I_video_latency_valid&&!I_latency_fault&&I_cfg_done&&!I_cfg_error;
    wire [41:0] source_raw_counts;
    wire learning,preview_ready;wire [35:0] candidate;
    reg audit_clear_tracks;
    reg audit_seen_packet;reg [15:0] audit_quality_sequence;
    always @(posedge I_clk or negedge I_rst_n)begin
      if(!I_rst_n)begin audit_clear_tracks<=0;audit_seen_packet<=0;audit_quality_sequence<=0;end
      else if(!detect_enable)begin audit_clear_tracks<=0;audit_seen_packet<=0;end
      else if(packet_commit&&(!audit_seen_packet||stable_sequence!=audit_quality_sequence))begin
        audit_clear_tracks<=!(|held_tracks)&&!moving;
        audit_seen_packet<=1;audit_quality_sequence<=stable_sequence;
      end
    end
    wire learn_ok=audit_clear_tracks&&!moving&&(source_raw_counts==audit_counts);
    scene_source113 source_tag(.clk(I_clk),.rst_n(I_rst_n),.enable(detect_enable),
      .capture_start(frame_tick&&det_valid&&!busy),.tag_sample(vd[1]&&px==16&&py==0),
      .packet_commit(packet_commit),.raw_sequence(seq),.stable_sequence(stable_sequence),
      .video_frame(I_video_frame),.now_ms(I_latency_now_ms[15:0]),.video_ms(I_video_ms),.stream_ok(source_ok),.raw_status(flags),.raw_counts(counts),.source_counts(source_raw_counts),
      .observation(source_observation),.observation_valid(source_valid),.source_frame(source_id),.source_stamp(source_stamp),.source_status(source_status));
    scene_audit113 audit(.clk(I_clk),.rst_n(I_rst_n),.enable(I_audit_enable&&detect_enable),
      .learn_ok(learn_ok),.light_low(I_light_state==2'd2),.light_mean(I_light_mean),
      .learning(learning),.preview_ready(preview_ready),.candidate(candidate),
      .capture_toggle(I_baseline_request),.observation(source_observation),.observation_valid(source_valid),.stream_ok(source_ok),
      .now_ms(I_latency_now_ms[15:0]),.source_frame(source_id),.source_stamp(source_stamp),.status(source_status),.counts(audit_counts),
      .baseline(baseline),.missing_amount(missing_amount),.missing(missing),.state(audit_state),.alarm(O_alarm));

    focus114 focus(.clk(I_clk),.rst_n(I_rst_n),.enable(detect_enable),
      .start(blank_start&&!track_busy),.next_toggle(I_audit_request),
      .objects(stable_obj),.held(held_tracks),.classes(stable_cls),.x0(stable_x0),.x1(stable_x1),.y0(stable_y0),.y1(stable_y1),
      .auto_mode(focus_auto),.moving(focus_moving),.valid(panel_focus_valid),.hold_state(focus_hold),.id(panel_focus_id),.cx(focus_x),.cy(focus_y),.busy(focus_busy));
    wire [15:0] result_ms,average_ms,max_ms,latency_samples;wire latency_valid;
    result_latency77 result_latency(.clk(I_clk),.rst_n(I_rst_n),.enable(detect_enable),
      .capture_tick(frame_tick&&det_valid&&!busy),.display_tick(frame_tick&&packet_ready),
      .now_ms(I_latency_now_ms),.raw_seq(seq),.stable_seq(packet_sequence),
      .result_ms(result_ms),.average_ms(),.max_ms(),.valid(latency_valid),.samples());
    always @(posedge I_clk or negedge I_rst_n)begin
      if(!I_rst_n)begin packet_active<=0;packet_ready<=0;packet_timer<=0;packet_sequence<=0;end
      else if(blank_start)begin packet_active<=!track_busy;packet_timer<=1;end
      else if(packet_active)begin
        if(packet_timer==180)begin
          packet_active<=0;packet_timer<=0;
          if(!focus_busy)begin packet_ready<=1;packet_sequence<=stable_sequence;end
        end else packet_timer<=packet_timer+1'b1;
      end
    end
    wire [127:0] decimal_digits;
    reg [6:0] decimal_delay;
    always @(posedge I_clk or negedge I_rst_n)begin
      if(!I_rst_n)decimal_delay<=0;
      else if(blank_start&&!track_busy)decimal_delay<=1;
      else if(decimal_delay!=0)decimal_delay<=decimal_delay==100?0:decimal_delay+1'b1;
    end
    wire latency_decimal_update;
    wire latency_read_video_valid=I_video_latency_valid&&!I_latency_fault&&I_cfg_done&&!I_cfg_error;
    latency_refresh104 readout_refresh(.clk(I_clk),.rst_n(I_rst_n),
      .frame_start(blank_start),.safe_tick(decimal_delay==100&&!focus_busy),
      .video_valid(latency_read_video_valid),
      .result_valid(latency_valid&&latency_read_video_valid&&detect_enable),
      .update(latency_decimal_update));
    panel_decimal98 decimal_panel(.clk(I_clk),.rst_n(I_rst_n),.start(latency_decimal_update),
      .video_ms(I_video_ms),.result_ms(result_ms),.digits(decimal_digits));
    wire [47:0] info_digits;
    panel_info105 info_panel(.clk(I_clk),.rst_n(I_rst_n),.start(decimal_delay==100&&!focus_busy),
      .x(focus_x),.y(focus_y),.hits(motion_hits),.digits(info_digits));
    scene_overlay116 renderer(
      .clk(I_clk),.rst_n(I_rst_n),.de(render_de),.hs(render_hs),.vs(render_vs),
      .overlay_enable(render_overlay),.x(render_x),.y(render_y),.rgb(display_pixel),.objects(stable_obj),
      .box_x0(stable_x0),.box_x1(stable_x1),.box_y0(stable_y0),.box_y1(stable_y1),.classes(stable_cls),
      .rates({cam_rate,hdmi_rate,det_rate}),.decimal_digits(decimal_digits),
      .info_digits(info_digits),.motion_state(motion_state),
      .focus_auto(focus_auto),.focus_moving(focus_moving),.focus_held(focus_hold),.focus_x(focus_x),.focus_y(focus_y),
      .video_valid(I_video_latency_valid),.latency_valid(latency_valid),.latency_fault(I_latency_fault),
      .video_frame(I_video_frame),.repeat_frames(I_repeat_frames),.skip_frames(I_skip_frames),
      .light_gain_r(I_light_gain_r),.light_gain_b(I_light_gain_b),.light_state(I_light_state),.light_mean(I_light_mean),.focus_valid(panel_focus_valid),.focus_id(panel_focus_id),.audit_state(audit_state),.learning(learning),.preview_ready(preview_ready),.candidate(candidate),.baseline(baseline),.missing(missing),.missing_amount(missing_amount),
      .motion_box(motion_box),.mx0(mx0),.mx1(mx1),.my0(my0),.my1(my1),.mean_level(I_mean),
      .display_mode(render_mode),.counts(stable_counts),.status(flags),.sequence_id(seq),.diagnostics(diagnostics),
      .video_status({stall_sync2,I_und_cnt}),.update_safe(!track_busy),.packet_commit(packet_commit),
      .rx_drops(I_rx_drops),.cfg_done(I_cfg_done),.cfg_error(I_cfg_error),
      .out_de(O_hdmi_de),.out_hs(O_hdmi_hsync),.out_vs(O_hdmi_vsync),
      .out_rgb(O_hdmi_data));
    assign O_target_flag=(|stable_obj);
endmodule

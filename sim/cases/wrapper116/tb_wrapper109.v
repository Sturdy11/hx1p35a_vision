
`timescale 1ns/1ps
module tb_wrapper109;
 reg[1:0] light=1;reg[7:0]mean=97;reg[35:0]pending_counts=36'h123456789;
 reg clk=0,rst_n=0,en=1,preview=1,armed=0;reg[2:0]mode=0;
 reg vs=0,hs=0,de=0,user=0,last=0;wire ren,ode,ohs,ovs,target,hb;wire[23:0]rgb;wire[3:0]led;
 reg[23:0]data=24'h385243;integer cycles=0,frame_count=0;
 always #5 clk=~clk;
 video_overlay116 #(.TAIL_FILL_PIXELS(0)) dut(.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),.I_video_last(last),
 .I_camera_frame_pulse(1'b0),.I_rx_drops(8'd0),.I_cfg_done(1'b1),.I_cfg_error(1'b0),.I_latency_now_ms(cycles/75000),.I_video_ms(16'd45),.I_video_frame(frame_count>>1),.I_repeat_frames(16'd1),.I_skip_frames(16'd0),.I_video_latency_valid(1'b1),.I_latency_fault(1'b0),.O_video_rd_en(ren),.I_video_rd_data(data),
 .I_light_gain_r(12'd256),.I_light_gain_b(12'd256),.I_light_state(light),.I_light_mean(mean),.I_ctrl_mode(mode),.I_audit_request(armed),.I_audit_enable(1'b1),.I_baseline_request(1'b1),.O_alarm(),.I_ctrl_param(4'd0),.I_ctrl_osd_en(preview),.I_ctrl_detect_en(en),
 .I_ctrl_th_bin(8'd0),.I_ctrl_th_edge(8'd8),.I_ctrl_strength(2'd0),.I_stat_valid(1'b0),
 .I_mean(8'd0),.I_tgt_cx(11'd0),.I_tgt_cy(10'd0),.I_tgt_area(20'd0),
 .I_bbox_x0(11'd0),.I_bbox_x1(11'd0),.I_bbox_y0(10'd0),.I_bbox_y1(10'd0),
 .I_global_bbox_bus(172'd0),.I_global_cls(8'd0),.I_global_area(96'd0),.I_und_cnt(4'd0),.I_stall_cnt(4'd0),
 .O_hdmi_de(ode),.O_hdmi_hsync(ohs),.O_hdmi_vsync(ovs),.O_hdmi_data(rgb),.O_led(led),.O_target_flag(target),.O_heartbeat(hb));

 task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
 task blank;begin de=0;vs=1;tick(5);vs=0;tick(190);end endtask
 integer k;
 initial begin
  tick(3);rst_n=1;tick(10);blank;
  if(dut.display_mode!=0||!dut.overlay_enable||!dut.detect_enable)$fatal(1,"enhance defaults");
  de=1;tick(20);mode=5;preview=0;tick(20);
  if(dut.display_mode!=0||!dut.overlay_enable||!dut.detect_enable)$fatal(1,"active frame changed");
  blank;if(dut.display_mode!=5||dut.overlay_enable||dut.detect_enable)$fatal(1,"raw not pure");
  de=1;tick(20);if(dut.display_pixel!==data)$fatal(1,"raw tone not bypassed");
  preview=1;tick(20);blank;
  if(dut.overlay_enable||dut.detect_enable)$fatal(1,"raw overlay/detection unexpectedly enabled");
  mode=0;tick(20);if(dut.display_mode!=5)$fatal(1,"mode changed without frame boundary");
  blank;if(dut.display_mode!=0||!dut.overlay_enable||!dut.detect_enable)$fatal(1,"return from raw failed");
  preview=0;blank;if(dut.overlay_enable||!dut.detect_enable)$fatal(1,"OSD off stops detection");
  mode=3;blank;if(dut.overlay_enable||dut.display_mode!=3||!dut.detect_enable)$fatal(1,"segment coupled to OSD");
  de=1;tick(20);if(dut.display_pixel!==(dut.pixel_mask?24'hffffff:24'h001000))$fatal(1,"segment missing");
  mode=4;blank;
  if(dut.display_mode!=4||!dut.detect_enable)$fatal(1,"edge mode paused recognition");
  de=1;tick(30);if(dut.display_pixel!==0)$fatal(1,"Sobel first-row border is not black");
  preview=1;blank;if(!dut.overlay_enable||!dut.detect_enable)$fatal(1,"edge OSD mode coupled to detection");

  light=2;mean=97;#1;if(!dut.source_ok)$fatal(1,"LOW source blocked");
  mean=47;#1;if(dut.source_ok)$fatal(1,"deep dark accepted");mean=48;#1;if(!dut.source_ok)$fatal(1,"floor boundary");
  light=0;#1;if(dut.source_ok)$fatal(1,"adjusting accepted");light=3;#1;if(dut.source_ok)$fatal(1,"waiting accepted");light=1;
  force dut.source_raw_counts=42'h123;force dut.audit_counts=42'h123;force dut.audit_clear_tracks=1;#1;
  if(!dut.learn_ok)$fatal(1,"valid count agreement rejected");force dut.source_raw_counts=42'h124;#1;if(dut.learn_ok)$fatal(1,"raw mismatch accepted");
  force dut.source_raw_counts=42'h123;force dut.audit_clear_tracks=0;#1;if(dut.learn_ok)$fatal(1,"held/moving accepted");
  release dut.source_raw_counts;release dut.audit_counts;release dut.audit_clear_tracks;
  force dut.learning=1;force dut.preview_ready=1;force dut.audit_state=2;force dut.candidate=pending_counts;
  force dut.packet_commit=1;force dut.track_busy=0;tick(2);release dut.packet_commit;release dut.track_busy;#1;
  $display("HUD pending=%h/%h flags=%b%b inputs=%b%b packet=%b safe=%b",dut.candidate,dut.renderer.snap_candidate,dut.renderer.snap_learning,dut.renderer.snap_preview,dut.learning,dut.preview_ready,dut.packet_commit,!dut.track_busy);
  if(dut.renderer.snap_candidate!==36'h123456789||!dut.renderer.snap_preview||!dut.renderer.snap_learning)$fatal(1,"candidate snapshot");
  if(dut.renderer.audit_char(3'd2,0)!="C"||dut.renderer.audit_char(3'd2,4)!="K")$fatal(1,"CHECK text");
  force dut.renderer.s_x=12'd8;force dut.renderer.s_y=12'd88;#1;if(dut.renderer.ch!="C")$fatal(1,"CAND row");
  force dut.renderer.s_x=12'd32;#1;if(dut.renderer.ch!="D")$fatal(1,"CAND spelling");
  release dut.renderer.s_x;release dut.renderer.s_y;
  release dut.learning;release dut.preview_ready;release dut.audit_state;release dut.candidate;
  $display("PASS wrapper116: active-frame requests deferred; original pure and unenhanced; OSD independent, recognition survives OSD off; detection resumes after original");$finish;
 end
endmodule

`timescale 1ns/1ps
module tb_fullvideo83;
 reg clk=0,rst_n=0,en=1,preview=1;reg [2:0] mode=0;reg armed=0;
 `include "reference69.vh"
 always #5 clk=~clk;
 wire vs,hs,de,user,last,ren,ode,ohs,ovs,target,hb;wire [23:0] rgb;wire [3:0] led;
 reg [23:0] pixels[0:921599],d0=0,data=0;
 integer xx=0,yy=0,cycles=0,good=0,frame_count=0,i;
 reg prev_vs=0,locked=0,disabled=0;
 uivtc #(.H_ActiveSize(1280),.H_FrameSize(1650),.H_SyncStart(1390),.H_SyncEnd(1430),
 .V_ActiveSize(720),.V_FrameSize(750),.V_SyncStart(725),.V_SyncEnd(730)) vtc(
 .I_vtc_rstn(rst_n),.I_vtc_clk(clk),.O_vtc_vs(vs),.O_vtc_hs(hs),.O_vtc_de_valid(de),.O_vtc_user(user),.O_vtc_last(last));
 video_overlay116 #(.TAIL_FILL_PIXELS(0)) dut(.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),.I_video_last(last),
 .I_camera_frame_pulse(1'b0),.I_rx_drops(8'd0),.I_cfg_done(1'b1),.I_cfg_error(1'b0),.I_latency_now_ms(cycles/75000),.I_video_ms(16'd45),.I_video_frame(frame_count>>1),.I_repeat_frames(16'd1),.I_skip_frames(16'd0),.I_video_latency_valid(1'b1),.I_latency_fault(1'b0),.O_video_rd_en(ren),.I_video_rd_data(data),
 .I_light_gain_r(12'd256),.I_light_gain_b(12'd256),.I_light_state(2'd2),.I_light_mean(8'd97),.I_ctrl_mode(mode),.I_audit_request(armed),.I_audit_enable(1'b1),.I_baseline_request(1'b1),.O_alarm(),.I_ctrl_param(4'd0),.I_ctrl_osd_en(preview),.I_ctrl_detect_en(en),
 .I_ctrl_th_bin(8'd0),.I_ctrl_th_edge(8'd8),.I_ctrl_strength(2'd0),.I_stat_valid(1'b0),
 .I_mean(8'd0),.I_tgt_cx(11'd0),.I_tgt_cy(10'd0),.I_tgt_area(20'd0),
 .I_bbox_x0(11'd0),.I_bbox_x1(11'd0),.I_bbox_y0(10'd0),.I_bbox_y1(10'd0),
 .I_global_bbox_bus(172'd0),.I_global_cls(8'd0),.I_global_area(96'd0),.I_und_cnt(4'd0),.I_stall_cnt(4'd0),
 .O_hdmi_de(ode),.O_hdmi_hsync(ohs),.O_hdmi_vsync(ovs),.O_hdmi_data(rgb),.O_led(led),.O_target_flag(target),.O_heartbeat(hb));
 reg [7:0] reference_gray[0:921599];
 reg [23:0] expected_pipe[0:4],er,ec;
 reg [14:0] sync_pipe=0;
 integer gval,gx,gy,axp,ayp,idx,qi,edge_checks=0,all_checks=0;
 // Store a complete reference image, independently of the RTL's line FIFOs.
 always @(posedge clk)begin
  if(rst_n)begin
   er=expected69(dut.shown_pixel);gval=(er[23:16]+2*er[15:8]+er[7:0])/4;
   axp=dut.px;ayp=dut.py;idx=ayp*1280+axp;
   if(dut.vd[1])reference_gray[idx]=gval;
   case(dut.display_mode)
    0:ec=er;1:ec={gval[7:0],gval[7:0],gval[7:0]};
    2:ec=gval>=dut.display_threshold?24'hffffff:0;
    3:ec=dut.pixel_mask?24'hffffff:24'h001000;
    5:ec=dut.shown_pixel;
    4:begin gx=0;gy=0;
     if(dut.vd[1]&&axp>=2&&ayp>=2)begin
      gx=reference_gray[idx-2560]+2*reference_gray[idx-1280]+reference_gray[idx]-reference_gray[idx-2562]-2*reference_gray[idx-1282]-reference_gray[idx-2];
      gy=reference_gray[idx-2]+2*reference_gray[idx-1]+reference_gray[idx]-reference_gray[idx-2562]-2*reference_gray[idx-2561]-reference_gray[idx-2560];
      if(gx<0)gx=-gx;if(gy<0)gy=-gy;
     end
     ec=dut.vd[1]&&axp>=2&&ayp>=2&&gx+gy>=dut.edge_threshold*8?24'hffffff:0;
    end
    default:ec=er;
   endcase
   for(qi=4;qi>0;qi=qi-1)expected_pipe[qi]=expected_pipe[qi-1];expected_pipe[0]=ec;
   sync_pipe={sync_pipe[11:0],dut.vd[1],dut.hd[1],dut.sd[1]};
   #1;
   if(cycles>10&&(dut.display_pixel!==expected_pipe[4]||{dut.render_de,dut.render_hs,dut.render_vs}!==sync_pipe[14:12]))$fatal(1,"full-frame display reference mismatch at %0d,%0d mode%0d",dut.render_x,dut.render_y,dut.render_mode);
   all_checks=all_checks+1;
  end
 end
 always @(posedge clk) begin
  if(!rst_n)begin xx<=0;yy<=0;prev_vs<=0;end
  else begin
   prev_vs<=vs;
   if(vs&&!prev_vs) begin xx<=0;yy<=0;end
   else if(de)begin if(xx==1279)begin xx<=0;yy<=yy==719?0:yy+1;end else xx<=xx+1;end
  end
  d0<=pixels[yy*1280+xx];data<=d0;
  #1;
  if(rst_n) begin
   cycles=cycles+1;
   if(dut.vd[1]&&dut.detector.rgb!==(dut.tail?24'd0:data))$fatal(1,"recognition RGB changed");
   if(dut.render_de&&dut.render_mode==4&&dut.display_pixel==24'hffffff)edge_checks=edge_checks+1;
   if(dut.vd[1]&&dut.px==1&&dut.py==0) begin
    frame_count=frame_count+1;
    if(disabled) begin
     if(edge_checks<1000||all_checks<10000000)$fatal(1,"insufficient edge/full-video coverage");
     if(dut.renderer.snap_v!=0||dut.renderer.snap_counts!=0) $fatal(1,"disable did not clear displayed tracks");
     $display("PASS fullvideo116 full17 video five processed modes including Sobel, 24-slot tracking: %0d stable displayed frames, threshold20, 17 targets, RGB/mask/Sobel full-frame oracle, independent OSD, disable; clocks=%0d",good,cycles);$finish;
    end
    if(dut.renderer.snap_counts==42'h06182041040) locked=1;
    if(locked) begin
     if(dut.renderer.snap_counts!==42'h06182041040) $fatal(1,"displayed targets blinked frame=%0d counts=%h",frame_count,dut.renderer.snap_counts);
     if(dut.detector.level!=20) $fatal(1,"clean frame threshold changed");
     good=good+1;
     $display("DISPLAY frame=%0d stable=%0d counts=%h rawQ=%0d",frame_count,good,dut.renderer.snap_counts,dut.seq);
     preview=good[0];mode=good%5;armed=~armed;
     if(good>=2)begin
      if(!dut.panel_focus_valid||dut.focus_x>1279||dut.focus_y>719||dut.focus_busy)$fatal(1,"selected tracking coordinates invalid");
      if(dut.motion_state!=2||dut.motion_box||dut.motion_hits!=0)$fatal(1,"static scene reported motion");
      if(!dut.latency_valid||dut.result_ms<25||dut.result_ms>150)$fatal(1,"result latency missing/implausible %0d",dut.result_ms);
     end
     if(good==5) begin
      if(dut.detector.light_map_sequence==0)$fatal(1,"no automatic regional map was committed");
      for(i=0;i<48;i=i+1)if(dut.detector.illumination.map_mem[{dut.detector.illumination.active_bank,6'd0}+i]!=16)$fatal(1,"uniform background introduced a local threshold drift");
      if(!dut.frame_guard.have_frame||dut.frame_guard.last_id==0||dut.O_alarm)$fatal(1,"fresh camera frame confirmation missing or false alarm");
      if(!dut.source_tag.valid[0]&&!dut.source_tag.valid[1])$fatal(1,"no source tags exercised");
      if(dut.audit.baseline!=0||!dut.learning||dut.candidate!==36'h186081041)$fatal(1,"LOW candidate or auto baseline");
      en=0;disabled=1;end
    end
   end
   if(cycles>25000000) $fatal(1,"integration timeout good=%0d",good);
  end
 end
 initial begin $readmemh("full17.mem",pixels);#22;rst_n=1;end
endmodule

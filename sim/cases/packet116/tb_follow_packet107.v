`timescale 1ns/1ps
// Controlled classifier outputs; actual tracker, focus, BCD and renderer.
module tb_follow_packet107;
 reg clk=0,rst=0,vs=0,de=0,next_focus=0;always #5 clk=~clk;
 reg [15:0] raw_seq=0;reg [15:0] video_fid=5;reg [215:0] bx0=0,bx1=0;reg [191:0] by0=0,by1=0;reg [71:0] cls=0;
 wire ren,ode,ohs,ovs,alarm,target,hb;wire [23:0] pixel;wire [3:0] led;
 integer f,i,packets=0;reg [15:0] frozen_seq;reg prior_active=0;
 video_overlay116 dut(.I_clk(clk),.I_rst_n(rst),.I_video_vsync(vs),.I_video_hsync(1'b0),.I_video_de(de),.I_video_user(1'b0),.I_video_last(1'b0),
 .I_camera_frame_pulse(1'b0),.O_video_rd_en(ren),.I_video_rd_data(24'h103020),
 .I_light_gain_r(12'd256),.I_light_gain_b(12'd256),.I_light_state(2'd1),.I_light_mean(8'd176),.I_ctrl_mode(3'd0),.I_audit_request(next_focus),.I_baseline_request(1'b0),.I_audit_enable(1'b0),.O_alarm(alarm),.I_latency_now_ms(24'd500),.I_video_ms(16'd30),
 .I_video_frame(video_fid),.I_repeat_frames(16'd1),.I_skip_frames(16'd0),.I_video_latency_valid(1'b1),.I_latency_fault(1'b0),
 .I_rx_drops(8'd0),.I_cfg_done(1'b1),.I_cfg_error(1'b0),.I_ctrl_param(4'd0),.I_ctrl_osd_en(1'b1),.I_ctrl_detect_en(1'b1),
 .I_ctrl_th_bin(8'd64),.I_ctrl_th_edge(8'd0),.I_ctrl_strength(2'd0),.I_stat_valid(1'b0),.I_mean(8'd40),
 .I_tgt_cx(11'd0),.I_tgt_cy(10'd0),.I_tgt_area(20'd0),.I_bbox_x0(11'd0),.I_bbox_x1(11'd0),.I_bbox_y0(10'd0),.I_bbox_y1(10'd0),
 .I_global_bbox_bus(172'd0),.I_global_cls(8'd0),.I_global_area(96'd0),.I_und_cnt(4'd0),.I_stall_cnt(4'd0),
 .O_hdmi_vsync(ovs),.O_hdmi_hsync(ohs),.O_hdmi_de(ode),.O_hdmi_data(pixel),.O_led(led),.O_target_flag(target),.O_heartbeat(hb));
 function integer decimal;input [15:0] d;begin decimal=d[15:12]*1000+d[11:8]*100+d[7:4]*10+d[3:0];end endfunction
 always @(posedge clk)begin
  if(rst&&dut.packet_active)begin
   if(!prior_active)frozen_seq=dut.stable_sequence;
   if(dut.track_busy||dut.stable_sequence!=frozen_seq)$fatal(1,"tracker changed while formatting packet");
  end
  prior_active=dut.packet_active;
  if(rst&&dut.packet_commit)begin
   #1;packets=packets+1;
   if(dut.renderer.snap_v!==dut.stable_obj||dut.renderer.snap_x0!==dut.stable_x0||dut.renderer.snap_c!==dut.stable_cls)
    $fatal(1,"packet descriptors are not one stable generation");
   if(packets>=4)begin
    if(dut.renderer.snap_v!=1||dut.renderer.snap_c[2:0]!=5||
       dut.renderer.snap_x0[8:0]!=(80+(f-1)*6)||dut.renderer.snap_x1[8:0]!=(100+(f-1)*6+((f-1)%2)*4)||
       dut.renderer.snap_y0[7:0]!=(50+(f-1)*4)||dut.renderer.snap_y1[7:0]!=(70+(f-1)*4))
     $fatal(1,"published cotton lags latest complete generation packet%0d x=%0d..%0d",packets,dut.renderer.snap_x0[8:0],dut.renderer.snap_x1[8:0]);
   end
   if(dut.renderer.snap_focus)begin
    i=dut.renderer.snap_id;
    if(!dut.renderer.snap_v[i])$fatal(1,"focus refers to absent slot");
    if(dut.renderer.snap_fx!=((dut.renderer.snap_x0[i*9+:9]+dut.renderer.snap_x1[i*9+:9])*2+1)||
       dut.renderer.snap_fy!=((dut.renderer.snap_y0[i*8+:8]+dut.renderer.snap_y1[i*8+:8])*2+1))$fatal(1,"focus descriptor mismatch");
    if(decimal(dut.renderer.snap_info[0+:16])!=dut.renderer.snap_fx||decimal(dut.renderer.snap_info[16+:16])!=dut.renderer.snap_fy)
     $fatal(1,"numeric coordinates differ from crosshair");
   end
  end
 end
 initial begin
  force dut.seq=raw_seq;force dut.obj=24'h000001;force dut.bx0=bx0;force dut.bx1=bx1;force dut.by0=by0;force dut.by1=by1;
  force dut.cls=cls;force dut.flags=4'd0;force dut.diagnostics=96'd0;force dut.busy=1'b0;
  #12;rst=1;
  // Prime one completed-image tag before injecting the first classifier result.
  @(negedge clk);de=1;repeat(24)@(negedge clk);de=0;repeat(8)@(negedge clk);
  for(f=0;f<10;f=f+1)begin
   @(negedge clk);vs=1;next_focus=~next_focus;repeat(8)@(negedge clk);
   if(!dut.packet_active)$fatal(1,"packet assembly did not start");
   for(i=0;i<1;i=i+1)begin bx0[i*9+:9]=80+f*6;bx1[i*9+:9]=100+f*6+(f%2)*4;
    by0[i*8+:8]=50+f*4;by1[i*8+:8]=70+f*4;cls[i*3+:3]=5;end
   raw_seq=raw_seq+1;vs=0;repeat(300)@(negedge clk);
   video_fid=f+6;de=1;repeat(24)@(negedge clk);de=0;repeat(5000)@(negedge clk);
  end
  if(packets!=10||!dut.renderer.snap_focus||dut.renderer.snap_v!=24'h000001)$fatal(1,"insufficient packet coverage %0d",packets);
  $display("PASS packet116 latest complete moving-cotton generation commits, moderate outline changes, original slot/crosshair/BCD coherence and atomic blanking update");$finish;
 end
endmodule

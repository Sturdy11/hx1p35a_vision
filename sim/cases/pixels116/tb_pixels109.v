`timescale 1ns/1ps
module tb_pixels109;
 reg clk=0,rst_n=0,de=0,safe=1,overlay=1;integer frame=0;reg[11:0]x=0,y=0;wire[23:0]pixel;wire ode,ohs,ovs;
 wire[23:0]old_pixel;wire old_de,old_hs,old_vs;reg[23:0]rgb=0;
 reg[215:0]x0=10,x1=20;reg[191:0]y0=50,y1=60;
 reg [23:0] objects=1;reg [71:0] classes=3;reg [41:0] counts=0;
 integer j;reg[95:0]diag=96'h0134000d075d100810081008;
 always #5 clk=~clk;
 scene_overlay116 dut(.focus_auto(1'b0),.focus_moving(1'b0),.learning(1'b0),.preview_ready(1'b0),.candidate(36'd0),.overlay_enable(overlay),.info_digits(48'h001804000900),.motion_state(3'd2),.clk(clk),.rst_n(rst_n),.de(de),.hs(1'b0),.vs(1'b0),.x(x),.y(y),.rgb(rgb),
 .light_gain_r(12'd256),.light_gain_b(12'd256),.light_state(2'd1),.light_mean(8'd176),.packet_commit(de&&x==0&&y==0),.rx_drops(8'd0),.cfg_done(1'b1),.cfg_error(1'b0),.display_mode(2'd2),.rates(24'h306020),.decimal_digits(128'h00000000567812340000000000000000),
 .focus_held(1'b1),.focus_x(12'd900),.focus_y(12'd400),.video_valid(1'b1),.latency_valid(1'b1),.latency_fault(1'b0),.video_frame(16'h1234),.repeat_frames(16'h0005),.skip_frames(16'h0002),.focus_valid(1'b1),.focus_id(5'd23),.audit_state(3'd0),.missing_amount(36'd0),.baseline(36'd0),.missing(6'b100000),
 .motion_box(1'b0),.mx0(12'd0),.mx1(12'd0),.my0(12'd0),.my1(12'd0),.mean_level(8'd72),
 .objects(objects),.box_x0(x0),.box_x1(x1),.box_y0(y0),.box_y1(y1),.classes(classes),.counts(counts),.status(4'd0),.sequence_id(16'd7),.update_safe(safe),.video_status(8'h00),.diagnostics(diag),
 .out_de(ode),.out_hs(ohs),.out_vs(ovs),.out_rgb(pixel));

 scene_overlay108 reference(.info_digits(48'h001804000900),.motion_state(3'd2),.clk(clk),.rst_n(rst_n),.de(de),.hs(1'b0),.vs(1'b0),.x(x),.y(y),.rgb(rgb),
 .light_gain_r(12'd256),.light_gain_b(12'd256),.light_state(2'd1),.light_mean(8'd176),.packet_commit(de&&x==0&&y==0),.rx_drops(8'd0),.cfg_done(1'b1),.cfg_error(1'b0),.display_mode(2'd2),.rates(24'h306020),.decimal_digits(128'h00000000567812340000000000000000),
 .focus_held(1'b1),.focus_x(12'd900),.focus_y(12'd400),.video_valid(1'b1),.latency_valid(1'b1),.latency_fault(1'b0),.video_frame(16'h1234),.repeat_frames(16'h0005),.skip_frames(16'h0002),.focus_valid(1'b1),.focus_id(5'd23),.audit_state(3'd0),.missing_amount(36'd0),.baseline(36'd0),.missing(6'b100000),
 .motion_box(1'b0),.mx0(12'd0),.mx1(12'd0),.my0(12'd0),.my1(12'd0),.mean_level(8'd72),
 .objects(objects),.box_x0(x0),.box_x1(x1),.box_y0(y0),.box_y1(y1),.classes(classes),.counts(counts),.status(4'd0),.sequence_id(16'd7),.update_safe(safe),.video_status(8'h00),.diagnostics(diag),
 .out_de(old_de),.out_hs(old_hs),.out_vs(old_vs),.out_rgb(old_pixel));

 reg[11:0]qx0=0,qx1=0,qx2=0,qx3=0,qy0=0,qy1=0,qy2=0,qy3=0;
 reg[23:0]pr0=0,pr1=0,pr2=0,pr3=0;
 reg qd0=0,qd1=0,qd2=0,qd3=0;integer samples=0,compared=0,xx,yy;
 always @(posedge clk)begin
  pr0<=rgb;pr1<=pr0;pr2<=pr1;pr3<=pr2;
  qx0<=x;qx1<=qx0;qx2<=qx1;qx3<=qx2;qy0<=y;qy1<=qy0;qy2<=qy1;qy3<=qy2;
  qd0<=de;qd1<=qd0;qd2<=qd1;qd3<=qd2;
  #1;if(rst_n)begin
   if({ode,ohs,ovs}!=={old_de,old_hs,old_vs}||ode!==qd3)$fatal(1,"video synchronization changed");
   if(ode)begin
    samples=samples+1;
    if(!overlay)begin compared=compared+1;if(pixel!==pr3)$fatal(1,"OSD off modified pixel %d,%d",qx3,qy3);end
    else if(!(qx3>=8&&qx3<400&&qy3>=8&&qy3<136))begin
     compared=compared+1;if(pixel!==old_pixel)$fatal(1,"non-HUD pixel differs %d,%d",qx3,qy3);
    end
   end
  end
 end
 initial begin
  objects=24'hffffff;classes=0;counts=0;x0=0;x1=0;y0=0;y1=0;
  for(j=0;j<24;j=j+1)begin x0[j*9+:9]=110+(j%6)*32;x1[j*9+:9]=130+(j%6)*32;y0[j*8+:8]=20+(j/6)*38;y1[j*8+:8]=45+(j/6)*38;classes[j*3+:3]=j%7;counts[(j%7)*6+:6]=counts[(j%7)*6+:6]+1;end
  #12;rst_n=1;
  for(frame=0;frame<3;frame=frame+1)begin
  overlay=(frame!=1);
  for(yy=0;yy<720;yy=yy+1)for(xx=0;xx<1280;xx=xx+1)begin @(negedge clk);x=xx;y=yy;de=1;rgb={xx[7:0],yy[7:0],8'ha5};end
  @(negedge clk);de=0;repeat(6)@(negedge clk);
  end
  if(samples!=2764800||compared!=2664448)$fatal(1,"pixel coverage %d %d",samples,compared);
  $display("PASS pixels116: 2764800 streamed; all 921600 OSD-off pixels exactly transparent including HUD/boxes/focus/logo; enable restores overlays; unchanged four-clock sync");$finish;
 end
endmodule

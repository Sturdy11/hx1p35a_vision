
`timescale 1ns/1ps
module tb_white_stream108;
 reg clk=0,rst_n=0,valid=0,enable=1;reg[11:0]x=0,y=0;reg[23:0]rgb=0;
 wire [23:0]objects,old_objects;wire[71:0]classes,old_classes;wire[215:0]x0,x1;wire[191:0]y0,y1;wire[41:0]counts,old_counts;wire[3:0]status,old_status;wire busy,old_busy;
 scene_detect116 #(.W(320),.H(240),.LOCAL_ADAPT(0)) dut(.clk(clk),.rst_n(rst_n),.valid(valid),.enable(enable),.x(x),.y(y),.rgb(rgb),.objects(objects),.classes(classes),.box_x0(x0),.box_x1(x1),.box_y0(y0),.box_y1(y1),.counts(counts),.status(status),.busy(busy));
 scene_detect102 #(.W(320),.H(240),.LOCAL_ADAPT(0)) old(.clk(clk),.rst_n(rst_n),.valid(valid),.enable(enable),.x(x),.y(y),.rgb(rgb),.objects(old_objects),.classes(old_classes),.counts(old_counts),.status(old_status),.busy(old_busy));
 always #5 clk=~clk;
 integer xx,yy,k,i,testno,cx,cy,rad,ddx,ddy,nt,ot;reg hit;
 task frame;input integer mode,px,py;begin
  @(negedge clk);enable=0;repeat(3)@(negedge clk);enable=1;repeat(140)@(negedge clk);
  cx=px;cy=py;rad=20;
  for(yy=0;yy<240;yy=yy+1)for(xx=0;xx<320;xx=xx+1)begin
   @(negedge clk);valid=1;x=xx;y=yy;rgb={8'd16,8'd35,8'd14};
   ddx=xx-cx;ddy=yy-cy;hit=ddx*ddx+ddy*ddy<=rad*rad;
   if(mode==2)rgb={8'd112,8'd180,8'd108};
   if(mode==3&&xx>=cx-40&&xx<=cx+26&&yy>=cy-80&&yy<=cy)rgb={8'd118,8'd88,8'd65};
   if(mode!=2&&mode!=5&&hit)begin
    rgb=mode==1?24'hb4b0ac:mode==4?24'h5a6c58:{8'd106,8'd126,8'd102};
    if(mode==3&&yy<cy-8)rgb={8'd118,8'd88,8'd65};
   end
  end
  @(negedge clk);valid=0;k=0;
  while((busy||old_busy)&&k<1000000)begin @(negedge clk);k=k+1;end
  if(k>=1000000||status!=0||old_status!=0)$fatal(1,"stream failed mode=%0d status=%h/%h cycles=%0d",mode,status,old_status,k);
  nt=0;ot=0;for(i=0;i<24;i=i+1)begin
   if(objects[i]&&classes[i*3+:3]==5)begin
    nt=nt+1;
    if(x0[i*9+:9]*4>cx+4||x1[i*9+:9]*4<cx-4||y0[i*8+:8]*4>cy+12||y1[i*8+:8]*4<cy-12)$fatal(1,"cotton bound misplaced");
   end
   if(old_objects[i]&&old_classes[i*3+:3]==5)ot=ot+1;
  end
  if((mode==0||mode==3)&&(nt!=1||ot!=0))$fatal(1,"reflected cotton recovery failed mode=%0d new=%0d old=%0d",mode,nt,ot);
  if(mode==1&&(nt!=1||ot!=1))$fatal(1,"normal white regression");
  if((mode==2||mode==4||mode==5)&&(nt!=0||ot!=0))$fatal(1,"negative became cotton mode=%0d",mode);
  $display("CASE mode%0d center%0d,%0d cotton new%0d old%0d cycles%0d",mode,cx,cy,nt,ot,k);
 end endtask
 initial begin #12;rst_n=1;
  frame(0,60,120);frame(0,160,120);frame(0,260,120);
  frame(1,160,120);frame(2,160,120);frame(3,160,120);frame(4,160,120);frame(5,160,120);
  $display("PASS white_stream116_l1: true streamed RGB, position-independent reflected cotton, normal white, partial hand, saturated cloth/dim/empty negatives, old detector reproduction");$finish;
 end

 always @(posedge clk)if(dut.state==dut.FSPLIT&&dut.tool_mode)begin if(dut.mid_box!==dut.sht*dut.mid_rows)$fatal(1,"stale blade product");end
endmodule

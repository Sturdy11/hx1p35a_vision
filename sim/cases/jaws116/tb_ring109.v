
`timescale 1ns/1ps
module tb_ring109;
 reg clk=0,rst_n=0,en=1,valid=0;reg[11:0]x=0,y=0;reg[23:0]rgb=0;
 wire[23:0]obj,oldobj;wire[71:0]cl,oldcl;wire[215:0]x0,x1;wire[191:0]y0,y1;
 wire busy,ob;wire[3:0]status,os;wire[41:0]counts,oc;
 always #5 clk=~clk;
 scene_detect116 #(.W(480),.H(480),.LOCAL_ADAPT(0)) dut(.clk(clk),.rst_n(rst_n),.enable(en),.valid(valid),.x(x),.y(y),.rgb(rgb),.objects(obj),.classes(cl),.box_x0(x0),.box_x1(x1),.box_y0(y0),.box_y1(y1),.busy(busy),.status(status),.counts(counts));
 scene_detect108 #(.W(480),.H(480),.LOCAL_ADAPT(0)) old(.clk(clk),.rst_n(rst_n),.enable(en),.valid(valid),.x(x),.y(y),.rgb(rgb),.objects(oldobj),.classes(oldcl),.busy(ob),.status(os),.counts(oc));
 integer xx,yy,u,v,a,b,z,dx,dy,r2,turn,kind,k,i,sc,he,ne,oldne;reg hit;
 function integer shape;input integer a,b,mode;
 integer dx,dy,r2;reg v;
 begin
  v=0;
  // Two finger rings. Upper/lower glint gaps isolate the right outer arc.
  dx=a-38;dy=b-94;r2=dx*dx+dy*dy;
  if(r2>=49&&r2<=81)v=1;
  dx=a-58;dy=b-94;r2=dx*dx+dy*dy;
  if(r2>=49&&r2<=81)v=1;
  if(a>=61&&b>=86&&b<=88)v=0;
  if(a>=61&&b>=100&&b<=102)v=0;
  // Handles/hinge remain connected to the inner ring surfaces.
  if(b>=53&&b<=88&&((a>=39&&a<=40)||(a>=56&&a<=57)))v=1;
  if(b>=50&&b<=55&&a>=39&&a<=57)v=1;
  // True scissors have a sustained thick distal blade; hemostat jaws stay thin.
  if(b>=18&&b<=53&&mode!=2&&a>=47-(mode==0?2:0)&&a<=48+(mode==0?2:mode==3?1:mode==4?2:0))v=1;
  if(b>=18&&b<=53&&mode==2&&
     ((a>=47-(53-b)/5&&a<=49-(53-b)/5)||(a>=47+(53-b)/5&&a<=49+(53-b)/5)))v=1;
  // Standalone needle by blade, then another outside the bounded ring gap.
  dx=a-75;dy=b-26;r2=dx*dx+dy*dy;if(r2>=49&&r2<=64&&b>=26)v=1;
  dx=a-91;dy=b-95;r2=dx*dx+dy*dy;if(r2>=49&&r2<=64&&b>=95)v=1;
  shape=v;
 end endfunction
 always @(posedge clk)begin
  if(dut.state==dut.FSPLIT&&dut.tool_mode)$display("PROFILE retry=%d rings=%d/%d core=%d blade=%d seed=%d distal=%d",dut.linear_retry,dut.ring_head,dut.ring_tail,dut.core_rings,dut.open_blade,dut.seeded_blade,dut.distal_blade);
  if(dut.state==dut.RPAIR)$display("PAIR anchor=%d ring=%d j=%d curve=%d arc=%d geom=%d supp=%d term=%d left/right=%d/%d",dut.mi,dut.c_ring_tool[dut.mi],dut.mj,dut.c_curve[dut.mj],dut.c_arc[dut.mj],dut.shaft_geometry,dut.j_arc_support,dut.j_terminal,dut.j_left,dut.j_right);
 end
 initial begin
  #12;rst_n=1;
  for(kind=0;kind<7;kind=kind+1)for(turn=0;turn<4;turn=turn+1)begin
   @(negedge clk);en=0;repeat(3)@(negedge clk);en=1;repeat(200)@(negedge clk);
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<480;xx=xx+1)begin
    @(negedge clk);valid=1;x=xx;y=yy;a=xx/4;b=yy/4;
    case(turn)0:begin u=a;v=b;end 1:begin u=b;v=119-a;end 2:begin u=119-a;v=119-b;end 3:begin u=119-b;v=a;end endcase
    rgb=shape(u,v,(kind==5?0:kind==6?1:kind))?24'hb0b0b0:24'h102010;
    if(kind>=5&&shape(u,v,(kind==5?0:1))&&v>=18&&v<=49&&u>=45&&u<=50&&u!=47)rgb=24'h222222;
   end
   @(negedge clk);valid=0;k=0;while((busy||ob)&&k<3000000)begin @(negedge clk);k=k+1;end
   if(busy||ob||status||os)$fatal(1,"deadline/status");
   $display("RING kind=%d rot=%d counts=%h old=%h",kind,turn,counts,oc);
   for(i=0;i<24;i=i+1)if(obj[i])$display("ROI class=%d bbox=%d,%d-%d,%d",cl[i*3+:3],x0[i*9+:9],y0[i*8+:8],x1[i*9+:9],y1[i*8+:8]);
   if(counts[6+:6]!=((kind==0||kind==2||kind==5)?1:0)||counts[18+:6]!=((kind==1||kind==3||kind==4||kind==6)?1:0)||counts[36+:6]!=2)$fatal(1,"ring repair/class/standalone needles");
  end
  $display("PASS jaws116: actual RGB, scissors/hemostats, four orientations, one detached ring arc reattached, blade-near and exterior needles retained");$finish;
 end

 always @(posedge clk)if(dut.state==dut.FSPLIT&&dut.tool_mode)begin if(dut.mid_box!==dut.sht*dut.mid_rows)$fatal(1,"stale blade product");end
endmodule

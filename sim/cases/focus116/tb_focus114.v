
`timescale 1ns/1ps
module tb_focus114;
 reg clk=0,rst=0,en=1,start=0,next=0;always #5 clk=~clk;
 reg [23:0] objects=0,held=0;reg[215:0] x0=0,x1=0;reg[191:0]y0=0,y1=0;reg[71:0]cls=0;
 wire valid,hold_state,busy,auto_mode,moving;wire[4:0]id;wire[11:0]cx,cy;
 focus114 dut(.clk(clk),.rst_n(rst),.enable(en),.start(start),.next_toggle(next),.objects(objects),.held(held),.x0(x0),.x1(x1),.y0(y0),.y1(y1),.classes(cls),.valid(valid),.hold_state(hold_state),.busy(busy),.id(id),.cx(cx),.cy(cy),.auto_mode(auto_mode),.moving(moving));
 integer n,k;reg [11:0] oldcx,oldcy;reg[4:0]oldid;
 task box;input integer slot,xx,yy;begin x0[slot*9+:9]=xx;x1[slot*9+:9]=xx+10;y0[slot*8+:8]=yy;y1[slot*8+:8]=yy+10;cls[slot*3+:3]=5;objects[slot]=1;end endtask
 task packet;begin
  @(negedge clk);start=1;@(negedge clk);start=0;k=0;
  oldcx=cx;oldcy=cy;oldid=id;
  while(busy&&k<100)begin
   @(negedge clk);k=k+1;
   if(busy&&(cx!==oldcx||cy!==oldcy||id!==oldid))$fatal(1,"torn scan output");
  end
  if(busy||k>74)$fatal(1,"scan budget %0d",k);
  if(valid&&(cx!==((x0[id*9+:9]+x1[id*9+:9])*2+1)||cy!==((y0[id*8+:8]+y1[id*8+:8])*2+1)))$fatal(1,"coordinates not selected packet");
 end endtask
 initial begin #12;rst=1;
  box(0,15,15);box(23,200,100);packet();if(id!=0||!auto_mode||moving)$fatal(1,"startup");
  box(23,205,103);packet();if(id!=23||!moving||!auto_mode||cx!=841)$fatal(1,"auto_mode mover not selected");
  for(n=0;n<5;n=n+1)begin box(23,210+n*5,106+n*3);packet();if(id!=23||!moving)$fatal(1,"moving ID lost");end
  box(0,35,25);box(23,236,121);packet();if(id!=23||!moving)$fatal(1,"two movers stole current moving target");
  // Repeated display packets keep the selected ID without counting stationary noise.
  for(n=0;n<8;n=n+1)packet();if(id!=23||moving)$fatal(1,"settled mover");
  @(negedge clk);next=~next;packet();if(id!=0||auto_mode)$fatal(1,"manual cycle");
  box(23,250,140);packet();if(id!=0||auto_mode)$fatal(1,"manual target stolen");
  box(0,25,25);packet();if(id!=0||!moving||cx!=121||cy!=121)$fatal(1,"manual coordinates did not follow");
  held[0]=1;packet();if(!hold_state||moving)$fatal(1,"held position shown live");
  en=0;@(negedge clk);@(negedge clk);if(valid||!auto_mode)$fatal(1,"disable");en=1;
  held=0;packet();if(moving)$fatal(1,"history not reset");
  cls[23*3+:3]=3;box(23,270,145);cls[23*3+:3]=3;packet();if(moving)$fatal(1,"class change mistaken as motion");
  objects=0;packet();if(valid||moving)$fatal(1,"empty scene");
  box(23,308,168);packet();if(id!=23||cx!=1253||cy!=693||moving)$fatal(1,"edge/slot23");
  $display("PASS focus116 auto movement, stationary repetition, manual selection, live coordinates, held/empty/disable/class-change/edge; atomic <=74 clocks");$finish;
 end
endmodule

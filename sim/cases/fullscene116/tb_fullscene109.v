
`timescale 1ns/1ps
module tb_fullscene109;
 reg clk=0,rst_n=0,en=1,valid=0;reg[11:0]x=0,y=0;reg[23:0]rgb=0;reg[23:0]pixels[0:921599];
 wire[41:0]counts;wire[3:0]status;wire busy;wire[15:0]seq;
 always #5 clk=~clk;
 scene_detect116 dut(.clk(clk),.rst_n(rst_n),.enable(en),.valid(valid),.x(x),.y(y),.rgb(rgb),.counts(counts),.status(status),.busy(busy),.sequence_id(seq));
 integer xx,yy,k;
 always @(posedge clk)if(dut.state==dut.FSPLIT&&dut.tool_mode)$display("PROFILE bbox=%d,%d-%d,%d ring=%d/%d seed=%d/%d bright=%d/%d distal=%d/%d solid=%d open=%d midspan=%d midhits=%d midrows=%d clutter=%d",dut.xmin,dut.ymin,dut.xmax,dut.ymax,dut.ring_head,dut.ring_tail,dut.seed_head,dut.seed_tail,dut.bright_head,dut.bright_tail,dut.distal_head,dut.distal_tail,dut.solid_blade,dut.open_blade,dut.mid_span,dut.mid_hits,dut.mid_rows,dut.clutter_frame);
 initial begin
  $readmemh("full17.mem",pixels);#12;rst_n=1;repeat(200)@(negedge clk);
  for(yy=0;yy<720;yy=yy+1)for(xx=0;xx<1280;xx=xx+1)begin @(negedge clk);valid=1;x=xx;y=yy;rgb=pixels[yy*1280+xx];end
  @(negedge clk);valid=0;k=0;while(busy&&k<3000000)begin @(negedge clk);k=k+1;end
  if(busy||status||seq!=1||counts!==42'h06182041040)$fatal(1,"six-class regression counts=%h status=%h",counts,status);
  $display("PASS fullscene116: streamed 720p six classes; S1 T1 H1 G2 C6 N6; threshold=%0d cycles=%0d",dut.level,k);$finish;
 end

 always @(posedge clk)if(dut.state==dut.FSPLIT&&dut.tool_mode)begin if(dut.mid_box!==dut.sht*dut.mid_rows)$fatal(1,"stale blade product");end
endmodule

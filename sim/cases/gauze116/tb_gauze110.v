
`timescale 1ns/1ps
module tb_gauze110;
reg clk=0,rst_n=0,en=1,tick=0;reg[15:0]seq=0;
reg[23:0]obs=0;reg[215:0]x0=0,x1=0;reg[191:0]y0=0,y1=0;reg[71:0]cl=0;
wire[23:0]obj;wire[41:0]counts;wire busy;wire[15:0]outseq;
always #5 clk=~clk;
scene_stabilize110 dut(.clk(clk),.rst_n(rst_n),.enable(en),.frame_tick(tick),.hold_updates(1'b0),.sequence_id(seq),.status(4'd0),.in_objects(obs),.in_x0(x0),.in_x1(x1),.in_y0(y0),.in_y1(y1),.in_classes(cl),.in_ring_ends(48'd0),.objects(obj),.counts(counts),.result_sequence(outseq),.busy(busy));
task reset_case;begin @(negedge clk);en=0;repeat(3)@(negedge clk);en=1;seq=0;obs=0;repeat(3)@(negedge clk);end endtask
task box;input integer slot,a,b,c,d;begin obs[slot]=1;x0[slot*9+:9]=a;x1[slot*9+:9]=b;y0[slot*8+:8]=c;y1[slot*8+:8]=d;cl[slot*3+:3]=4;end endtask
task commit;integer k;begin @(negedge clk);seq=seq+1;repeat(2)@(negedge clk);k=0;while((busy||outseq!=seq)&&k<50000)begin @(negedge clk);k=k+1;end if(k>=50000)$fatal(1,"tracker deadline");end endtask
integer i,j;
initial begin #12;rst_n=1;
// Near-identical current detections must not acquire two tracks, either order.
for(j=0;j<2;j=j+1)begin reset_case;for(i=0;i<6;i=i+1)begin obs=0;box(j,100,150,70,120);box(1-j,102,152,73,123);commit;end
if(counts[24+:6]!=1)$fatal(1,"duplicate order %d count=%d",j,counts[24+:6]);end
// Distinct adjacent rectangles, and two partially overlapping rectangles, stay two.
for(j=0;j<2;j=j+1)begin reset_case;for(i=0;i<6;i=i+1)begin obs=0;box(0,100,150,70,120);box(1,j==0?153:125,j==0?203:175,70,120);commit;end
if(counts[24+:6]!=2)$fatal(1,"distinct gauze over-suppressed");end
// Two established tracks converge: retire the old held rectangle, prefer current.
reset_case;for(i=0;i<4;i=i+1)begin obs=0;box(0,100,150,70,120);box(1,160,210,70,120);commit;end
for(j=0;j<4;j=j+1)begin obs=0;box(0,100,150,70,120);box(1,145-j*15,195-j*15,70,120);commit;end
for(i=0;i<8;i=i+1)begin obs=0;box(0,100,150,70,120);commit;end
if(counts[24+:6]!=1)$fatal(1,"held duplicate was not retired count=%d",counts[24+:6]);
// Suppression is class-specific: cotton and needle contracts are separate tests.
$display("PASS gauze116: both duplicate input orders, adjacent and partially overlapping gauzes, existing held-track convergence, bounded packet deadline");$finish;
end
endmodule

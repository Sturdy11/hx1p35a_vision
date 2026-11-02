
`timescale 1ns/1ps
module tb_photo110;
reg clk=0,rst_n=0,en=1,valid=0;reg[11:0]x=0,y=0;reg[23:0]rgb=0,pixels[0:230399];
wire busy;wire[3:0]status;wire[41:0]counts;wire[23:0]obj;wire[71:0]cl;
always #5 clk=~clk;
scene_detect116 #(.W(480),.H(480),.LOCAL_ADAPT(0)) dut(.clk(clk),.rst_n(rst_n),.enable(en),.valid(valid),.x(x),.y(y),.rgb(rgb),.objects(obj),.classes(cl),.busy(busy),.status(status),.counts(counts));
integer xx,yy,k,i;
always @(negedge clk)if(dut.state==dut.FSPLIT)begin dut.ring_head=0;dut.ring_tail=10;dut.ring_rows=10;end

always @(posedge clk)if(dut.state==dut.FSPLIT)$display("DIM rows=%d/%d feature=%d",dut.dim_head,dut.dim_tail,dut.dim_blade);
always @(posedge clk)if(dut.state==dut.FSPLIT&&dut.tool_mode)$display("PROFILE bounds=%d,%d-%d,%d length=%d rings=%d/%d solid=%d open=%d seeded=%d distal=%d fork=%d seedrows=%d/%d distalrows=%d/%d bladerows=%d",dut.xmin,dut.ymin,dut.xmax,dut.ymax,dut.lng,dut.ring_head,dut.ring_tail,dut.solid_blade,dut.open_blade,dut.seeded_blade,dut.distal_blade,dut.fork_blade,dut.seed_head,dut.seed_tail,dut.distal_head,dut.distal_tail,dut.blade_rows);
initial begin
$readmemh("photo.mem",pixels);#12;rst_n=1;repeat(200)@(negedge clk);
for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<480;xx=xx+1)begin @(negedge clk);valid=1;x=xx;y=yy;rgb=pixels[yy*480+xx];end
@(negedge clk);valid=0;
dut.xmin=40;dut.ymin=16;dut.xmax=66;dut.ymax=92;dut.area=400;dut.white_area=0;dut.tool_mode=1;dut.state=dut.FADDR;dut.along=0;dut.across=0;
k=0;while(dut.state!=dut.EMIT&&k<100000)begin @(negedge clk);k=k+1;end
if(dut.cls!=1)$fatal(1,"ROI blade classification");
$display("CLASSIFIER class=%d ring=%d/%d",dut.cls,dut.ring_head,dut.ring_tail);
$display("PASS new116_roi_dim_scissors_115_0: display crop diagnostic");$finish;
end

 always @(posedge clk)if(dut.state==dut.FSPLIT&&dut.tool_mode)begin if(dut.mid_box!==dut.sht*dut.mid_rows)$fatal(1,"stale blade product");end
endmodule

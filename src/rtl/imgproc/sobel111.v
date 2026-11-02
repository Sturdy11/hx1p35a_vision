module sobel111 #(parameter W=1280,H=720)(
 input wire clk,rst_n,valid,
 input wire [11:0] x,y,input wire [7:0] gray,threshold,
 output reg out_valid,output reg edge_pixel
);
 localparam AW=$clog2(W);
 (* ram_style="block" *) reg [7:0] row1[0:W-1]; //synthesis ram_style=bram
 (* ram_style="block" *) reg [7:0] row2[0:W-1]; //synthesis ram_style=bram
 reg [7:0] q1,q2,g1,m2,b2;
 reg [AW-1:0] a1;
 reg [11:0] x1,y1,x2,y2;
 reg v1,v2,v3,v4,inside3,inside4;
 reg [7:0] tl2,tl1,ml2,ml1,bl2,bl1;
 reg [9:0] px,nx,py,ny,ax,ay;
 wire [10:0] magnitude={1'b0,ax}+{1'b0,ay};
 wire [10:0] limit={threshold,3'b000};

 always @(posedge clk)begin
  if(valid)begin q1<=row1[x[AW-1:0]];row1[x[AW-1:0]]<=gray;end
  if(v1)begin q2<=row2[a1];row2[a1]<=q1;end
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   v1<=0;v2<=0;v3<=0;v4<=0;out_valid<=0;edge_pixel<=0;
   a1<=0;g1<=0;m2<=0;b2<=0;x1<=0;y1<=0;x2<=0;y2<=0;
   tl2<=0;tl1<=0;ml2<=0;ml1<=0;bl2<=0;bl1<=0;
   px<=0;nx<=0;py<=0;ny<=0;ax<=0;ay<=0;inside3<=0;inside4<=0;
  end else begin
   v1<=valid;v2<=v1;v3<=v2;v4<=v3;out_valid<=v4;
   if(valid)begin a1<=x[AW-1:0];g1<=gray;x1<=x;y1<=y;end
   if(v1)begin m2<=q1;b2<=g1;x2<=x1;y2<=y1;end
   inside3<=v2&&x2>=2&&y2>=2;inside4<=inside3;
   if(v2)begin

    px<={2'b0,q2}+{1'b0,m2,1'b0}+{2'b0,b2};
    nx<={2'b0,tl2}+{1'b0,ml2,1'b0}+{2'b0,bl2};
    py<={2'b0,bl2}+{1'b0,bl1,1'b0}+{2'b0,b2};
    ny<={2'b0,tl2}+{1'b0,tl1,1'b0}+{2'b0,q2};
    tl2<=x2==0?8'd0:tl1;tl1<=q2;
    ml2<=x2==0?8'd0:ml1;ml1<=m2;
    bl2<=x2==0?8'd0:bl1;bl1<=b2;
   end
   ax<=px>=nx?px-nx:nx-px;ay<=py>=ny?py-ny:ny-py;
   edge_pixel<=v4&&inside4&&(magnitude>=limit);
  end
 end
endmodule

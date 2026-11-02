module display_modes111 #(parameter W=1280,H=720)(
 input wire clk,rst_n,de,hs,vs,overlay_enable,
 input wire [11:0] x,y,input wire [23:0] original_rgb,enhanced_rgb,
 input wire pixel_mask,input wire [2:0] mode,
 input wire [7:0] threshold,edge_threshold,
 output wire out_de,out_hs,out_vs,out_overlay,
 output wire [11:0] out_x,out_y,output wire [2:0] out_mode,
 output wire [23:0] rgb
);
 wire [9:0] sum={2'b0,enhanced_rgb[23:16]}+{1'b0,enhanced_rgb[15:8],1'b0}+{2'b0,enhanced_rgb[7:0]};
 wire [7:0] gray=sum[9:2];
 reg [23:0] base;
 always @*begin
  case(mode)
   0:base=enhanced_rgb;
   1:base={gray,gray,gray};
   2:base=gray>=threshold?24'hffffff:24'd0;
   3:base=pixel_mask?24'hffffff:24'h001000;
   5:base=original_rgb;
   default:base=enhanced_rgb;
  endcase
 end
 wire edge_valid,edge_bit;
 sobel111 #(.W(W),.H(H)) edges(.clk(clk),.rst_n(rst_n),.valid(de),.x(x),.y(y),.gray(gray),.threshold(edge_threshold),.out_valid(edge_valid),.edge_pixel(edge_bit));
 reg [23:0] color[0:4];reg [11:0] xx[0:4],yy[0:4];
 reg [2:0] mm[0:4];reg [4:0] dd,hh,vv,oo;
 integer i;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   dd<=0;hh<=0;vv<=0;oo<=0;
   for(i=0;i<5;i=i+1)begin color[i]<=0;xx[i]<=0;yy[i]<=0;mm[i]<=0;end
  end else begin
   dd<={dd[3:0],de};hh<={hh[3:0],hs};vv<={vv[3:0],vs};oo<={oo[3:0],overlay_enable};
   color[0]<=base;xx[0]<=x;yy[0]<=y;mm[0]<=mode;
   for(i=1;i<5;i=i+1)begin color[i]<=color[i-1];xx[i]<=xx[i-1];yy[i]<=yy[i-1];mm[i]<=mm[i-1];end
  end
 end
 assign out_de=dd[4];assign out_hs=hh[4];assign out_vs=vv[4];assign out_overlay=oo[4];
 assign out_x=xx[4];assign out_y=yy[4];assign out_mode=mm[4];
 assign rgb=mm[4]==4?((edge_valid&&edge_bit)?24'hffffff:24'd0):color[4];
endmodule

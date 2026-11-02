module motion_grid105 #(
 parameter WIDTH=1280,HEIGHT=720,DIFF=24,MIN_HITS=8,
 parameter CELLS=(WIDTH/8)*(HEIGHT/8),MAX_HITS=CELLS/3
)(
 input wire clk,rst_n,enable,frame_start,tag_sample,stream_ok,
 input wire [15:0] source_frame,
 input wire valid,input wire [11:0] x,y,input wire [23:0] rgb,
 output reg box_valid,output reg [11:0] x0,x1,y0,y1,
 output reg [14:0] hits,output reg [2:0] state
);
 localparam OFF=0,WAIT_REF=1,STILL=2,MOVE=3,LIGHT=4,STALE=5;
 reg [7:0] memory[0:CELLS-1];
 reg [7:0] previous_gray;
 reg active,compare,ref_valid,tag_seen;
 reg [15:0] active_id,ref_id;
 reg [13:0] address;
 reg [14:0] changed;
 reg [7:0] minx,maxx,miny,maxy;
 reg sample_d,compare_d;
 reg [13:0] address_d;
 reg [7:0] gray_d,gx_d,gy_d;
 wire [9:0] lum={2'b0,rgb[23:16]}+{1'b0,rgb[15:8],1'b0}+{2'b0,rgb[7:0]};
 wire sample=enable&&stream_ok&&active&&valid&&x<WIDTH&&y<HEIGHT&&
             x[2:0]==3'd4&&y[2:0]==3'd4&&address<CELLS;
 wire [15:0] delta=source_frame-ref_id;
 wire [8:0] difference=gray_d>=previous_gray?{1'b0,gray_d}-{1'b0,previous_gray}:
                                                     {1'b0,previous_gray}-{1'b0,gray_d};
 always @(posedge clk)begin
  if(sample)previous_gray<=memory[address];
  if(sample_d)memory[address_d]<=gray_d;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   active<=0;compare<=0;ref_valid<=0;tag_seen<=0;active_id<=0;ref_id<=0;
   address<=0;changed<=0;minx<=255;maxx<=0;miny<=255;maxy<=0;
   sample_d<=0;compare_d<=0;address_d<=0;gray_d<=0;gx_d<=0;gy_d<=0;
   box_valid<=0;x0<=0;x1<=0;y0<=0;y1<=0;hits<=0;state<=OFF;
  end else begin
   sample_d<=sample;compare_d<=compare;
   if(sample)begin
    address_d<=address;gray_d<=lum[9:2];gx_d<=x[10:3];gy_d<=y[10:3];
    address<=address+1'b1;
   end
   if(!enable||!stream_ok)begin
    active<=0;compare<=0;ref_valid<=0;tag_seen<=0;sample_d<=0;
    address<=0;changed<=0;box_valid<=0;hits<=0;state<=enable?STALE:OFF;
   end else if(frame_start)begin

    if(active)begin
     ref_valid<=address==CELLS;ref_id<=active_id;
     if(address!=CELLS)begin box_valid<=0;hits<=0;state<=STALE;end
     else if(!compare)begin box_valid<=0;hits<=0;state<=WAIT_REF;end
     else begin
      hits<=changed;
      box_valid<=changed>=MIN_HITS&&changed<=MAX_HITS;
      state<=changed>MAX_HITS?LIGHT:changed>=MIN_HITS?MOVE:STILL;
      x0<={1'b0,minx,3'b000};x1<={1'b0,maxx,3'b111};
      y0<={1'b0,miny,3'b000};y1<={1'b0,maxy,3'b111};
     end
    end
    active<=0;compare<=0;tag_seen<=0;address<=0;changed<=0;
    minx<=255;maxx<=0;miny<=255;maxy<=0;
   end else begin
    if(tag_sample&&!tag_seen)begin
     tag_seen<=1;
     if(!ref_valid||(delta!=0&&!delta[15]))begin
      active<=1;active_id<=source_frame;
      compare<=ref_valid&&delta<=4;
     end
    end
    if(sample_d&&compare_d&&difference>=DIFF)begin
     if(changed<CELLS)changed<=changed+1'b1;
     if(gx_d<minx)minx<=gx_d;if(gx_d>maxx)maxx<=gx_d;
     if(gy_d<miny)miny<=gy_d;if(gy_d>maxy)maxy<=gy_d;
    end
   end
  end
 end
endmodule

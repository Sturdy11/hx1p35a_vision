// Shared serial decimal converter. Atomic packet: {motion hits,Y,X},48 clocks.
module panel_info105(input wire clk,rst_n,start,
 input wire [11:0] x,y,input wire [14:0] hits,output reg [47:0] digits);
 reg running;reg [1:0] item;reg [3:0] bitn;
 reg [31:0] shift;reg [15:0] next_y,next_hits;reg [31:0] saved;
 reg [31:0] adjusted;integer j;
 always @*begin adjusted=shift;for(j=0;j<4;j=j+1)
  if(shift[16+j*4+:4]>=5)adjusted[16+j*4+:4]=shift[16+j*4+:4]+4'd3;end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin running<=0;item<=0;bitn<=0;shift<=0;next_y<=0;next_hits<=0;saved<=0;digits<=0;end
  else if(start&&!running)begin
   shift<={20'd0,x};next_y<={4'd0,y};next_hits<=hits>9999?16'd9999:{1'b0,hits};
   item<=0;bitn<=0;running<=1;
  end else if(running)begin
   shift<=adjusted<<1;
   if(bitn==15)begin
    bitn<=0;item<=item+1'b1;
    case(item)
     0:begin saved[15:0]<=adjusted[30:15];shift<={16'd0,next_y};end
     1:begin saved[31:16]<=adjusted[30:15];shift<={16'd0,next_hits};end
     default:begin digits<={adjusted[30:15],saved};running<=0;end
    endcase
   end else bitn<=bitn+1'b1;
  end
 end
endmodule

module panel_decimal77(
 input wire clk,rst_n,start,input wire [15:0] proc_ms,age_ms,
 input wire [11:0] cx,cy,input wire [15:0] video_ms,result_ms,average_ms,max_ms,output reg [127:0] digits
);
 reg [15:0] values[0:7];reg [2:0] item;reg [4:0] bitn;
 reg [31:0] shift;reg running;reg [127:0] work_digits;
 reg [31:0] adjusted;integer j,ri;
 always @* begin adjusted=shift;for(j=0;j<4;j=j+1)if(shift[16+j*4+:4]>=5)adjusted[16+j*4+:4]=shift[16+j*4+:4]+4'd3;end
 function [15:0] clipped;input [15:0] n;begin clipped=n>9999?16'd9999:n;end endfunction
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin digits<=0;work_digits<=0;shift<=0;running<=0;item<=0;bitn<=0;
   for(ri=0;ri<8;ri=ri+1)values[ri]<=0;end
  else if(start&&!running)begin
   values[0]<=clipped(proc_ms);values[1]<=clipped(age_ms);values[2]<={4'd0,cx};values[3]<={4'd0,cy};
   values[4]<=clipped(video_ms);values[5]<=clipped(result_ms);values[6]<=clipped(average_ms);values[7]<=clipped(max_ms);
   shift<={16'd0,clipped(proc_ms)};item<=0;bitn<=0;running<=1;
  end else if(running)begin
   shift<=adjusted<<1;
   if(bitn==15)begin
    work_digits[item*16+:16]<=adjusted[30:15];bitn<=0;
    if(item==7)begin digits<={adjusted[30:15],work_digits[111:0]};running<=0;end
    else begin item<=item+1'b1;shift<={16'd0,values[item+1'b1]};end
   end else bitn<=bitn+1'b1;
  end
 end
endmodule

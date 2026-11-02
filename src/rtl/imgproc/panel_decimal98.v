module panel_decimal98(input wire clk,rst_n,start,input wire[15:0]video_ms,result_ms,output reg[127:0]digits);
 reg running,item;reg[4:0]bitn;reg[31:0]shift;reg[15:0]next_value,video_digits;
 reg[31:0]adjusted;integer j;
 function[15:0]clip;input[15:0]n;begin clip=n>9999?16'd9999:n;end endfunction
 always @*begin adjusted=shift;for(j=0;j<4;j=j+1)if(shift[16+j*4+:4]>=5)adjusted[16+j*4+:4]=shift[16+j*4+:4]+4'd3;end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin digits<=0;running<=0;item<=0;bitn<=0;shift<=0;next_value<=0;video_digits<=0;end
  else if(start&&!running)begin shift<={16'd0,clip(video_ms)};next_value<=clip(result_ms);item<=0;bitn<=0;running<=1;end
  else if(running)begin
   shift<=adjusted<<1;
   if(bitn==15)begin
    bitn<=0;
    if(item)begin digits<={32'd0,adjusted[30:15],video_digits,64'd0};running<=0;end
    else begin video_digits<=adjusted[30:15];shift<={16'd0,next_value};item<=1;end
   end else bitn<=bitn+1'b1;
  end
 end
endmodule

module latency_refresh104 #(parameter FRAMES=60)(
 input wire clk,rst_n,frame_start,safe_tick,video_valid,result_valid,
 output wire update
);
 reg [5:0] frames;
 reg due,video_seen,result_seen;
 assign update=safe_tick&&(due||(video_valid&&!video_seen)||(result_valid&&!result_seen));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin frames<=0;due<=1;video_seen<=0;result_seen<=0;end
  else begin
   if(frame_start)begin
    if(frames==FRAMES-1)begin frames<=0;due<=1;end
    else frames<=frames+1'b1;
   end
   if(!video_valid)video_seen<=0;
   if(!result_valid)result_seen<=0;
   if(update)begin due<=0;video_seen<=video_valid;result_seen<=result_valid;end
  end
 end
endmodule

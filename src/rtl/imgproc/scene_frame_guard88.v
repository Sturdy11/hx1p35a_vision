// metadata settles. No image/FIFO/DDR control outputs. A rejected result still

module scene_frame_guard88 #(parameter MAX_SOURCE_AGE_MS=500)(
 input wire clk,rst_n,enable,capture_start,tag_sample,stream_ok,
 input wire [15:0] raw_sequence,video_frame,now_ms,video_ms,
 input wire [3:0] raw_status,
 output reg [15:0] result_sequence,output reg [3:0] result_status
);
 reg pending,tag_wait,tag_valid,have_frame;
 reg [15:0] captured_id,captured_stamp,seen_raw,last_id;
 wire [15:0] delta=captured_id-last_id,age_ms=now_ms-captured_stamp;
 wire usable=pending&&tag_valid&&stream_ok&&age_ms<MAX_SOURCE_AGE_MS&&
             !raw_status[0]&&!raw_status[2]&&!raw_status[3];
 wire new_id=!have_frame||(delta!=0&&!delta[15]);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   pending<=0;tag_wait<=0;tag_valid<=0;have_frame<=0;
   captured_id<=0;captured_stamp<=0;seen_raw<=0;last_id<=0;
   result_sequence<=0;result_status<=8;
  end else if(!enable)begin
   pending<=0;tag_wait<=0;tag_valid<=0;have_frame<=0;
   seen_raw<=raw_sequence;result_sequence<=raw_sequence;result_status<=8;
  end else begin
   if(tag_sample&&pending&&tag_wait)begin
    captured_id<=video_frame;captured_stamp<=now_ms-video_ms;
    tag_valid<=stream_ok&&video_ms<MAX_SOURCE_AGE_MS;tag_wait<=0;
   end
   if(raw_sequence!=seen_raw)begin
    seen_raw<=raw_sequence;pending<=0;result_sequence<=raw_sequence;
    result_status<=usable&&new_id?raw_status:(raw_status|4'b1000);
    if(usable&&new_id)begin have_frame<=1;last_id<=captured_id;end
   end

   if(capture_start)begin pending<=1;tag_wait<=1;tag_valid<=0;end
  end
 end
endmodule

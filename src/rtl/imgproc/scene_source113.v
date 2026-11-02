module scene_source113(
 input wire clk,rst_n,enable,capture_start,tag_sample,packet_commit,
 input wire [15:0] raw_sequence,stable_sequence,video_frame,now_ms,video_ms,
 input wire stream_ok,input wire [3:0] raw_status,input wire [41:0] raw_counts,
 output reg [41:0] source_counts,
 output reg observation,observation_valid,
 output reg [15:0] source_frame,source_stamp,output reg [3:0] source_status
);
 reg pending,tag_valid,tag_wait;reg [15:0] captured_id,captured_stamp,seen_raw,seen_stable;
 reg seen_packet;
 reg [15:0] tags[0:1],ids[0:1],stamps[0:1];reg [3:0] errors[0:1];reg [1:0] valid;
 reg [41:0] count_tags[0:1];
 integer i;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   pending<=0;tag_valid<=0;tag_wait<=0;captured_id<=0;captured_stamp<=0;seen_raw<=0;seen_stable<=0;seen_packet<=0;valid<=0;
   source_counts<=0;observation<=0;observation_valid<=0;source_frame<=0;source_stamp<=0;source_status<=0;
   for(i=0;i<2;i=i+1)begin count_tags[i]<=0;tags[i]<=0;ids[i]<=0;stamps[i]<=0;errors[i]<=0;end
  end else begin
   observation<=0;
   if(!enable)begin pending<=0;tag_valid<=0;tag_wait<=0;valid<=0;seen_raw<=raw_sequence;seen_packet<=0;end
   else begin
    if(tag_sample&&pending&&tag_wait)begin
     captured_id<=video_frame;captured_stamp<=now_ms-video_ms;tag_valid<=stream_ok;tag_wait<=0;
    end
    if(raw_sequence!=seen_raw)begin
     seen_raw<=raw_sequence;pending<=0;
     count_tags[raw_sequence[0]]<=raw_counts;tags[raw_sequence[0]]<=raw_sequence;ids[raw_sequence[0]]<=captured_id;
     stamps[raw_sequence[0]]<=captured_stamp;errors[raw_sequence[0]]<=raw_status;
     valid[raw_sequence[0]]<=pending&&tag_valid;
    end
    // Completion and next capture can coincide at a frame boundary. Store

    if(capture_start)begin pending<=1;tag_valid<=0;tag_wait<=1;end
    if(packet_commit&&(!seen_packet||stable_sequence!=seen_stable))begin
     seen_packet<=1;seen_stable<=stable_sequence;observation<=1;
     observation_valid<=valid[stable_sequence[0]]&&tags[stable_sequence[0]]==stable_sequence&&stream_ok;
     source_frame<=ids[stable_sequence[0]];source_stamp<=stamps[stable_sequence[0]];
     source_status<=errors[stable_sequence[0]];source_counts<=count_tags[stable_sequence[0]];
    end
   end
  end
 end
endmodule

module scene_audit113 #(
 parameter LEARN_VOTES=3,LEARN_MS=100,LOW_VOTES=8,LOW_MS=600,
 parameter MISS_VOTES=6,RECOVER_VOTES=2,CONFIRM_MS=500,STALE_MS=500
)(
 input wire clk,rst_n,enable,capture_toggle,observation,observation_valid,stream_ok,
 input wire learn_ok,light_low,input wire [7:0] light_mean,
 input wire [15:0] now_ms,source_frame,source_stamp,
 input wire [3:0] status,input wire [41:0] counts,
 output reg [35:0] baseline,missing_amount,output reg [5:0] missing,
 output wire [2:0] state,output wire alarm,
 output reg learning,preview_ready,output reg [35:0] candidate
);
 localparam OFF=0,WAIT_BASE=1,LEARN=2,MATCH=3,PENDING=4,MISSING=5,REVIEW=6,STALE=7;
 reg [1:0] good_review;
 reg capture_seen,base_valid,have_id,have_observation,review,timed_out,latest_ok,learn_low;
 reg [15:0] last_id,last_stamp,learn_since;
 reg [7:0] learn_mean;
 reg [3:0] learn_count;
 reg [35:0] pending_amount;
 reg [2:0] absent[0:5];reg [1:0] present[0:5];reg [15:0] since[0:5];
 wire [15:0] delta_id=source_frame-last_id;
 wire [15:0] sample_age=now_ms-source_stamp,last_age=now_ms-last_stamp;
 wire new_id=!have_id||(delta_id!=0&&!delta_id[15]);
 wire fresh=stream_ok&&have_observation&&!timed_out&&last_age<STALE_MS;
 wire sample_good=observation_valid&&stream_ok&&sample_age<STALE_MS;
 wire [8:0] mean_delta=light_mean>=learn_mean?{1'b0,light_mean}-{1'b0,learn_mean}:{1'b0,learn_mean}-{1'b0,light_mean};
 wire profile_same=learn_low==light_low&&(!light_low||mean_delta<=4);
 wire clean=sample_good&&status==0&&counts[5:0]==0;
 wire can_commit=preview_ready&&fresh&&!review&&latest_ok&&learn_ok&&profile_same&&
                 counts[41:6]==candidate&&counts[5:0]==0&&status==0&&
                 (!observation||(clean&&new_id));
 function [15:0] elapsed;input [15:0] a,b;begin elapsed=a-b;end endfunction
 reg deficit,surplus,pending_any;integer k,j;
 always @*begin
  deficit=0;surplus=0;pending_any=0;
  for(j=0;j<6;j=j+1)begin
   if(counts[(j+1)*6+:6]<baseline[j*6+:6])deficit=1;
   if(counts[(j+1)*6+:6]>baseline[j*6+:6])surplus=1;
   if(absent[j]!=0)pending_any=1;
  end
 end
 assign state=!enable?OFF:!fresh?STALE:review?REVIEW:learning?LEARN:!base_valid?WAIT_BASE:
              (|missing)?MISSING:pending_any?PENDING:MATCH;
 assign alarm=enable&&fresh&&base_valid&&!learning&&!review&&(|missing);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   good_review<=0;capture_seen<=0;learning<=0;base_valid<=0;have_id<=0;have_observation<=0;review<=0;timed_out<=1;
   latest_ok<=0;learn_low<=0;learn_since<=0;learn_mean<=0;preview_ready<=0;
   last_id<=0;last_stamp<=0;candidate<=0;pending_amount<=0;learn_count<=0;baseline<=0;missing<=0;missing_amount<=0;
   for(k=0;k<6;k=k+1)begin absent[k]<=0;present[k]<=0;since[k]<=0;end
  end else if(!enable)begin
   good_review<=0;capture_seen<=capture_toggle;learning<=0;base_valid<=0;have_id<=0;have_observation<=0;review<=0;timed_out<=1;
   latest_ok<=0;learn_count<=0;preview_ready<=0;candidate<=0;baseline<=0;missing<=0;missing_amount<=0;
   for(k=0;k<6;k=k+1)begin absent[k]<=0;present[k]<=0;since[k]<=0;end
  end else begin
   if(!stream_ok||(have_observation&&last_age>=STALE_MS))begin
    timed_out<=1;good_review<=0;latest_ok<=0;learn_count<=0;preview_ready<=0;
   end
   if(capture_toggle!=capture_seen)begin
    capture_seen<=capture_toggle;good_review<=0;review<=0;
    missing<=0;missing_amount<=0;
    for(k=0;k<6;k=k+1)begin absent[k]<=0;present[k]<=0;since[k]<=0;end
    if(learning&&can_commit)begin
     baseline<=candidate;base_valid<=1;learning<=0;preview_ready<=0;learn_count<=0;
    end else begin

     learning<=1;preview_ready<=0;learn_count<=0;latest_ok<=0;candidate<=0;
    end
   end else if(observation&&(!observation_valid||new_id))begin
    if(observation_valid)begin have_id<=1;last_id<=source_frame;end
    if(sample_good)begin have_observation<=1;last_stamp<=source_stamp;timed_out<=0;end
    if(!clean||(!learning&&base_valid&&deficit&&surplus))begin
     review<=1;good_review<=0;learn_count<=0;preview_ready<=0;latest_ok<=0;
     for(k=0;k<6;k=k+1)begin absent[k]<=0;present[k]<=0;end
    end else begin
     if(review&&(!fresh||good_review<2))begin good_review<=!fresh?2'd1:good_review+1'b1;review<=1;end
     else begin review<=0;good_review<=0;end
     if(learning)begin
      latest_ok<=learn_ok&&counts[41:6]!=0;
      if(!learn_ok||counts[41:6]==0)begin learn_count<=0;preview_ready<=0;end
      else if(!fresh||learn_count==0||candidate!=counts[41:6]||!profile_same)begin
       candidate<=counts[41:6];learn_count<=1;learn_since<=now_ms;
       learn_low<=light_low;learn_mean<=light_mean;preview_ready<=0;
      end else begin
       if(learn_count<15)learn_count<=learn_count+1'b1;
       if(learn_count>=(light_low?LOW_VOTES-1:LEARN_VOTES-1)&&
          elapsed(now_ms,learn_since)>=(light_low?LOW_MS:LEARN_MS))preview_ready<=1;
      end
     end else if(base_valid)begin
      for(k=0;k<6;k=k+1)begin
       if(counts[(k+1)*6+:6]<baseline[k*6+:6])begin
        present[k]<=0;
        if(!fresh||absent[k]==0||pending_amount[k*6+:6]!=(baseline[k*6+:6]-counts[(k+1)*6+:6]))begin
         absent[k]<=1;since[k]<=now_ms;pending_amount[k*6+:6]<=baseline[k*6+:6]-counts[(k+1)*6+:6];
        end else begin
         if(absent[k]<MISS_VOTES)absent[k]<=absent[k]+1'b1;
         if(absent[k]>=MISS_VOTES-1&&elapsed(now_ms,since[k])>=CONFIRM_MS)begin
          missing[k]<=1;missing_amount[k*6+:6]<=baseline[k*6+:6]-counts[(k+1)*6+:6];
         end
        end
       end else begin
        absent[k]<=0;if(present[k]<RECOVER_VOTES)present[k]<=present[k]+1'b1;
        if(present[k]>=RECOVER_VOTES-1)begin missing[k]<=0;missing_amount[k*6+:6]<=0;end
       end
      end
     end
    end
   end
  end
 end
endmodule

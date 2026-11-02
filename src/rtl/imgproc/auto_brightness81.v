module auto_brightness81(
 input wire clk,rst_n,sof,meter_toggle,meter_valid,allow_digital,wb_stable,
 input wire [7:0] meter_mean,meter_target,
 output reg [10:0] gain,output reg [1:0] light_state
);
 reg seen;reg [10:0] pending_gain;reg [1:0] low_votes;
 reg [18:0] product;reg [7:0] mean_snapshot,target_snapshot;reg valid_snapshot,wb_snapshot,limit_snapshot;
 reg pending;wire [10:0] predicted=product>>8;
 wire [10:0] band=target_snapshot<128?11'd4:11'd8;
 wire [10:0] stable_band=target_snapshot<128?({3'd0,target_snapshot}>>3):11'd16;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin seen<=0;pending_gain<=256;gain<=256;low_votes<=0;light_state<=3;product<=0;
   mean_snapshot<=0;target_snapshot<=0;valid_snapshot<=0;wb_snapshot<=0;limit_snapshot<=0;pending<=0;end
  else begin
   if(sof)gain<=pending_gain;
   seen<=meter_toggle;
   if(meter_toggle!=seen)begin
    product<=meter_mean*gain;mean_snapshot<=meter_mean;target_snapshot<=meter_target;
    valid_snapshot<=meter_valid;wb_snapshot<=wb_stable;limit_snapshot<=allow_digital;pending<=1;
   end else if(pending)begin
    pending<=0;
    if(!valid_snapshot)begin light_state<=3;low_votes<=0;end
    else begin
     if(predicted+band<{3'd0,target_snapshot}&&limit_snapshot)begin
      if(low_votes!=3)low_votes<=low_votes+1'b1;
      if(low_votes>=1)pending_gain<=gain>=380?384:gain+11'd4;
     end else begin
      low_votes<=0;
      if(predicted>{3'd0,target_snapshot}+band||(!limit_snapshot&&gain>256))pending_gain<=gain<=272?256:gain-11'd16;
     end
     if(!wb_snapshot)light_state<=0;
     else if(predicted+stable_band>={3'd0,target_snapshot}&&predicted<={3'd0,target_snapshot}+stable_band)light_state<=1;
     else if(limit_snapshot&&gain>=384&&predicted+stable_band<{3'd0,target_snapshot})light_state<=2;
     else light_state<=0;
    end
   end
  end
 end
endmodule

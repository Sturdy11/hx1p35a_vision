module result_latency77(
 input wire clk,rst_n,enable,capture_tick,display_tick,
 input wire [23:0] now_ms,input wire [15:0] raw_seq,stable_seq,
 output reg [15:0] result_ms,average_ms,max_ms,
 output reg valid,output reg [15:0] samples
);
 reg [23:0] capture_time,starts[0:1];reg [15:0] tags[0:1];
 reg [1:0] slot_valid;reg pending;reg [15:0] old_raw,old_display;
 reg [18:0] average_q3;
 wire [23:0] elapsed=now_ms-starts[stable_seq[0]];
 wire [15:0] clipped=elapsed>9999?16'd9999:elapsed[15:0];
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin capture_time<=0;pending<=0;old_raw<=0;old_display<=0;slot_valid<=0;
   starts[0]<=0;starts[1]<=0;tags[0]<=0;tags[1]<=0;
   result_ms<=0;average_ms<=0;average_q3<=0;max_ms<=0;valid<=0;samples<=0;
  end else if(!enable)begin pending<=0;slot_valid<=0;old_raw<=raw_seq;old_display<=stable_seq;
   result_ms<=0;average_ms<=0;average_q3<=0;max_ms<=0;valid<=0;samples<=0;
  end else begin
   if(capture_tick)begin capture_time<=now_ms;pending<=1;end
   if(raw_seq!=old_raw)begin
    old_raw<=raw_seq;
    slot_valid[raw_seq[0]]<=pending;
    starts[raw_seq[0]]<=capture_time;tags[raw_seq[0]]<=raw_seq;

    if(!capture_tick)pending<=0;
   end
   if(display_tick&&stable_seq!=old_display)begin
    old_display<=stable_seq;
    valid<=slot_valid[stable_seq[0]]&&tags[stable_seq[0]]==stable_seq&&elapsed<=9999;
    if(slot_valid[stable_seq[0]]&&tags[stable_seq[0]]==stable_seq&&elapsed<=9999)begin
     result_ms<=clipped;if(clipped>max_ms)max_ms<=clipped;
     if(samples==0)begin average_q3<={clipped,3'b0};average_ms<=clipped;end
     else begin
      average_q3<=average_q3-(average_q3>>3)+clipped;
      average_ms<=(average_q3-(average_q3>>3)+clipped)>>3;
     end
     if(samples!=65535)samples<=samples+1'b1;
    end
   end
  end
 end
endmodule

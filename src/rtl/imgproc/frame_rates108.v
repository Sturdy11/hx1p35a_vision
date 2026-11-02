module frame_rates108(
 input wire clk,rst_n,input wire[15:0]now_ms,
 input wire camera_tick,display_tick,detect_enable,
 input wire[15:0]result_sequence,input wire[3:0]result_status,
 output reg[23:0]rates
);
 reg primed;reg[15:0]window_start,seen_sequence;
 reg[7:0]camera_count,display_count,detect_count;
 wire[15:0]elapsed=now_ms-window_start;
 wire detect_tick=detect_enable&&result_sequence!=seen_sequence&&
                  !result_status[0]&&!result_status[2]&&!result_status[3];
 function[7:0]inc;input[7:0]v;begin
  if(v==8'h99)inc=v;
  else if(v[3:0]==9)inc={v[7:4]+4'd1,4'd0};
  else inc=v+8'd1;
 end endfunction
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin primed<=0;window_start<=0;seen_sequence<=0;
   camera_count<=0;display_count<=0;detect_count<=0;rates<=0;end
  else begin
   seen_sequence<=result_sequence;
   if(!primed)begin primed<=1;window_start<=now_ms;
    camera_count<=camera_tick?8'h01:8'h00;display_count<=display_tick?8'h01:8'h00;
    detect_count<=detect_tick?8'h01:8'h00;
   end else if(elapsed>=1000)begin
    // Boundary events belong to the new half-open [start,start+1000) window.
    rates<={camera_count,display_count,detect_count};window_start<=now_ms;
    camera_count<=camera_tick?8'h01:8'h00;display_count<=display_tick?8'h01:8'h00;
    detect_count<=detect_tick?8'h01:8'h00;
   end else begin
    if(camera_tick)camera_count<=inc(camera_count);
    if(display_tick)display_count<=inc(display_count);
    if(detect_tick)detect_count<=inc(detect_count);
   end
  end
 end
endmodule

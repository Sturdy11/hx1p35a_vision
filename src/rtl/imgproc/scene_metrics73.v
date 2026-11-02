module scene_metrics73 #(parameter CLK_HZ=75000000)(
 input wire clk,rst_n,frame_tick,camera_tick,capture_tick,
 input wire [15:0] sequence_id,
 output reg [7:0] camera_fps,display_fps,detect_fps,
 output reg [15:0] proc_ms,age_ms,
 output reg [15:0] now_ms,output wire [15:0] time_gray
);
 localparam MS_DIV=CLK_HZ/1000;
 reg [16:0] div;reg [9:0] seconds;
 reg [7:0] cc,hc,dc;reg [15:0] last_seq,start_ms;
 reg pending,have_result;
 wire ms_tick=div==MS_DIV-1;
 wire result_tick=sequence_id!=last_seq;
 function [7:0] inc_bcd;input [7:0] n;
 begin if(n>=8'h99)inc_bcd=8'h99;else if(n[3:0]==9)inc_bcd={n[7:4]+4'd1,4'd0};else inc_bcd=n+1'b1;end endfunction
 assign time_gray=now_ms^(now_ms>>1);
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n)begin div<=0;seconds<=0;cc<=0;hc<=0;dc<=0;camera_fps<=0;display_fps<=0;detect_fps<=0;
   now_ms<=0;last_seq<=0;start_ms<=0;proc_ms<=0;age_ms<=16'hffff;pending<=0;have_result<=0;end
  else begin
   if(ms_tick)begin
    div<=0;now_ms<=now_ms+1'b1;
    if(have_result&&age_ms!=16'hffff)age_ms<=age_ms+1'b1;
   end else div<=div+1'b1;
   if(capture_tick)begin start_ms<=now_ms;pending<=1;end
   if(result_tick)begin last_seq<=sequence_id;if(pending)begin proc_ms<=now_ms-start_ms;age_ms<=now_ms-start_ms;have_result<=1;pending<=0;end end
   if(ms_tick&&seconds==999)begin
    seconds<=0;camera_fps<=camera_tick?inc_bcd(cc):cc;display_fps<=frame_tick?inc_bcd(hc):hc;detect_fps<=result_tick?inc_bcd(dc):dc;
    cc<=0;hc<=0;dc<=0;
   end else begin
    if(ms_tick)seconds<=seconds+1'b1;
    if(camera_tick)cc<=inc_bcd(cc);if(frame_tick)hc<=inc_bcd(hc);if(result_tick)dc<=inc_bcd(dc);
   end
  end
 end
endmodule

module panel_decimal73(
 input wire clk,rst_n,start,input wire [15:0] proc_ms,age_ms,
 input wire [11:0] cx,cy,output reg [63:0] digits
);
 reg [15:0] values[0:3];reg [1:0] item;reg [4:0] bitn;
 reg [31:0] shift;reg running;reg [63:0] work_digits;
 reg [31:0] adjusted;integer j,ri;
 always @* begin adjusted=shift;for(j=0;j<4;j=j+1)if(shift[16+j*4+:4]>=5)adjusted[16+j*4+:4]=shift[16+j*4+:4]+4'd3;end
 function [15:0] clipped;input [15:0] n;begin clipped=n>9999?16'd9999:n;end endfunction
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin digits<=0;work_digits<=0;shift<=0;running<=0;item<=0;bitn<=0;
   for(ri=0;ri<4;ri=ri+1)values[ri]<=0;end
  else if(start&&!running)begin
   values[0]<=clipped(proc_ms);values[1]<=clipped(age_ms);values[2]<={4'd0,cx};values[3]<={4'd0,cy};
   shift<={16'd0,clipped(proc_ms)};item<=0;bitn<=0;running<=1;
  end else if(running)begin
   shift<=adjusted<<1;
   if(bitn==15)begin
    work_digits[item*16+:16]<=adjusted[30:15];bitn<=0;
    if(item==3)begin digits<={adjusted[30:15],work_digits[47:0]};running<=0;end
    else begin item<=item+1'b1;shift<={16'd0,values[item+1'b1]};end
   end else bitn<=bitn+1'b1;
  end
 end
endmodule

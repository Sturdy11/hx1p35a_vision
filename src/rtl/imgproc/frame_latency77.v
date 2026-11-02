// Observation only: no pixel/FIFO/DDR control output. Times are digital CSI SOF

module frame_latency77 #(parameter CLK_HZ=75000000)(
 input wire rst_n,cam_clk,ddr_clk,pix_clk,
 input wire raw_sof,ingress_sof,write_sof,input wire [1:0] write_slot,
 input wire write_commit,input wire [1:0] commit_slot,
 input wire display_commit,input wire [1:0] display_slot,input wire display_valid,
 input wire out_vs,out_de,
 output reg [15:0] video_ms,frame_id,repeat_frames,skip_frames,
 output reg video_valid,output wire fault,output wire [23:0] now_ms
);
 localparam DIV=CLK_HZ/1000;
 reg [16:0] divider;reg [23:0] timer,gray;
 assign now_ms=timer;
 always @(posedge pix_clk or negedge rst_n)begin
  if(!rst_n)begin divider<=0;timer<=0;gray<=0;end
  else if(divider==DIV-1)begin divider<=0;timer<=timer+1'b1;gray<=(timer+1'b1)^((timer+1'b1)>>1);end
  else divider<=divider+1'b1;
 end
 (* ASYNC_REG="TRUE" *) reg [23:0] cam_g1,cam_g2;
 function [23:0] ungray;input [23:0] value;integer k;begin
  ungray[23]=value[23];for(k=22;k>=0;k=k-1)ungray[k]=ungray[k+1]^value[k];
 end endfunction
 reg [15:0] cam_id;reg [23:0] cam_stamp;reg seen_raw;
 always @(posedge cam_clk or negedge rst_n)begin
  if(!rst_n)begin cam_g1<=0;cam_g2<=0;cam_id<=0;cam_stamp<=0;seen_raw<=0;end
  else begin
   cam_g1<=gray;cam_g2<=cam_g1;
   if(raw_sof)begin cam_id<=cam_id+1'b1;cam_stamp<=ungray(cam_g2);seen_raw<=1;end
  end
 end

 // Overflow/underflow is a sticky measurement fault: never report a shifted tag.
 reg [40:0] metadata[0:3];reg [2:0] wp,rp,wg,rg;
 (* ASYNC_REG="TRUE" *) reg [2:0] rg1,rg2,wg1,wg2;
 reg cam_fault,ddr_fault;
 wire full=wg=={~rg2[2:1],rg2[0]};wire empty=rg==wg2;
 wire [2:0] wn=wp+1'b1,rn=rp+1'b1;
 always @(posedge cam_clk or negedge rst_n)begin
  if(!rst_n)begin wp<=0;wg<=0;rg1<=0;rg2<=0;cam_fault<=0;end
  else begin
   rg1<=rg;rg2<=rg1;
   if(ingress_sof)begin
    if(full)cam_fault<=1;
    else begin
     metadata[wp[1:0]]<=raw_sof?{1'b1,cam_id+16'd1,ungray(cam_g2)}:{seen_raw,cam_id,cam_stamp};
     wp<=wn;wg<=wn^(wn>>1);
    end
   end
  end
 end
 reg [40:0] writing;reg [40:0] banks[0:3];
 reg [40:0] mailbox;reg request,ack;
 (* ASYNC_REG="TRUE" *) reg ack1,ack2,cf1,cf2;
 integer b;
 always @(posedge ddr_clk or negedge rst_n)begin
  if(!rst_n)begin rp<=0;rg<=0;wg1<=0;wg2<=0;writing<=0;mailbox<=0;request<=0;
   ack1<=0;ack2<=0;cf1<=0;cf2<=0;ddr_fault<=0;
   for(b=0;b<4;b=b+1)banks[b]<=0;
  end else begin
   wg1<=wg;wg2<=wg1;ack1<=ack;ack2<=ack1;cf1<=cam_fault;cf2<=cf1;
   if(write_sof)begin
    banks[write_slot][40]<=0;
    if(empty)begin writing<=0;ddr_fault<=1;end
    else begin writing<=metadata[rp[1:0]];rp<=rn;rg<=rn^(rn>>1);end
   end
   if(write_commit)banks[commit_slot]<={writing[40]&&!ddr_fault&&!cf2,writing[39:0]};
   if(display_commit)begin
    if(request==ack2)begin
     mailbox<={banks[display_slot][40]&&display_valid&&!ddr_fault&&!cf2,banks[display_slot][39:0]};
     request<=~request;
    end else ddr_fault<=1;
   end
  end
 end
 (* ASYNC_REG="TRUE" *) reg req1,req2,df1,df2;
 reg [40:0] presented;reg old_vs,armed,have_last,expired;
 reg [15:0] last_id;wire [15:0] delta=presented[39:24]-last_id;
 wire [23:0] elapsed=timer-presented[23:0];
 assign fault=df2;
 always @(posedge pix_clk or negedge rst_n)begin
  if(!rst_n)begin req1<=0;req2<=0;df1<=0;df2<=0;ack<=0;presented<=0;old_vs<=0;armed<=1;
   video_ms<=0;frame_id<=0;video_valid<=0;repeat_frames<=0;skip_frames<=0;have_last<=0;last_id<=0;expired<=0;
  end else begin
   req1<=request;req2<=req1;df1<=ddr_fault||cf2;df2<=df1;old_vs<=out_vs;
   if(req2!=ack)begin presented<=mailbox;ack<=req2;end
   if(out_vs&&!old_vs)armed<=1;
   if(out_de&&armed)begin
    armed<=0;
    if(presented[40]&&!df2)begin
     frame_id<=presented[39:24];
     if(!have_last||delta!=0)expired<=0;
     else if(elapsed>9999)expired<=1;
     video_valid<=elapsed<=9999&&(!expired||!have_last||delta!=0);
     video_ms<=elapsed>9999?16'd9999:elapsed[15:0];
     if(have_last)begin
      if(delta==0&&repeat_frames!=65535)repeat_frames<=repeat_frames+1'b1;
      else if(delta>1&&delta<32768)begin
       if({1'b0,skip_frames}+{1'b0,delta}-17'd1>65535)skip_frames<=65535;
       else skip_frames<=skip_frames+delta-1'b1;
      end
     end
     last_id<=presented[39:24];have_last<=1;
    end else video_valid<=0;
   end
  end
 end
endmodule

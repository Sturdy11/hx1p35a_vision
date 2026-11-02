// FIFO is reset at power-up, never by a marker concurrent with valid data.
module video_in78 # (parameter FRAME_WORDS=172800)(
 input wire I_rst_n,I_camera_clk,I_camera_frame_start,I_camera_valid,
 input wire [127:0] I_camera_data,input wire I_capture_enable,
 input wire I_mipi_rx_error,I_ddr_clk,I_display_pause,I_video_out_rd_busy,
 input wire [1:0] I_display_rp,input wire I_display_valid,
 input wire [1:0] I_pending_rp,input wire I_pending_valid,
 output wire [7:0] O_drop_gray,output reg O_ingress_fault,
 output wire O_ingress_sof,O_write_sof,O_write_commit,
 output wire [1:0] O_write_slot,O_commit_slot,
 output wire O_video_in_wr_busy,output reg [1:0] O_video_out_rp,
 output reg O_frame_ready,
 output reg O_ddr_user_wr_en,output wire [24:0] O_ddr_user_addr,
 output wire [127:0] O_ddr_user_wr_data,input wire I_ddr_user_ready
);
 function [24:0] base;input [1:0] p;begin
  case(p) 0:base=0;1:base=7000000;2:base=14000000;3:base=21000000;endcase
 end endfunction
 reg sof_pending,cam_open,cam_bad;
 reg [17:0] cam_words;
 reg [7:0] drops,drop_gray;
 wire [129:0] fifo_data;
 wire [8:0] fifo_count;
 wire fifo_empty,fifo_full;
 wire source_sof=I_camera_frame_start||sof_pending;
 wire admit=I_capture_enable&&I_camera_valid&&!fifo_full&&!I_mipi_rx_error&&
            (source_sof||(cam_open&&!cam_bad));
 wire source_last=!source_sof&&cam_words==FRAME_WORDS-1;
 assign O_drop_gray=drop_gray;
 always @(posedge I_camera_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin sof_pending<=0;cam_open<=0;cam_bad<=0;cam_words<=0;drops<=0;drop_gray<=0;O_ingress_fault<=0;end
  else if(!I_capture_enable)begin sof_pending<=0;cam_open<=0;cam_bad<=0;cam_words<=0;end
  else begin
   if(I_camera_valid)sof_pending<=0;
   else if(I_camera_frame_start)sof_pending<=1;
   if(I_camera_valid&&source_sof)begin
    cam_words<=1;cam_open<=1;cam_bad<=fifo_full||I_mipi_rx_error;
    if(fifo_full||I_mipi_rx_error)begin
     O_ingress_fault<=1;
     if(drops!=255)begin drops<=drops+1'b1;drop_gray<=(drops+8'd1)^((drops+8'd1)>>1);end
    end
   end else if(cam_open)begin
    if(!cam_bad&&(I_mipi_rx_error||(I_camera_valid&&fifo_full)))begin
     cam_bad<=1;O_ingress_fault<=1;
     if(drops!=255)begin drops<=drops+1'b1;drop_gray<=(drops+8'd1)^((drops+8'd1)>>1);end
    end
    if(I_camera_valid)begin
     if(source_last)begin cam_open<=0;cam_words<=0;end
     else cam_words<=cam_words+1'b1;
    end
   end
  end
 end
 reg burst;
 reg [7:0] burst_count,burst_words;
 reg [9:0] drain_wait;
 wire fifo_read=burst&&I_ddr_user_ready&&!fifo_empty;

 soft_fifo_al_4057d6b76aa6 #(.DATA_WIDTH_W(130),.DATA_WIDTH_R(130),
  .ADDR_WIDTH_W(9),.ADDR_WIDTH_R(9),.AL_FULL_NUM(480),.AL_EMPTY_NUM(2),
  .SHOW_AHEAD_EN(0),.OUTREG_EN("NOREG")) U_frame_fifo(
  .rst(!I_rst_n),.clkw(I_camera_clk),.clkr(I_ddr_clk),.we(admit),
  .di({source_last,source_sof,I_camera_data}),.re(fifo_read),
  .dout(fifo_data),.valid(),.full_flag(fifo_full),.empty_flag(fifo_empty),
  .afull(),.aempty(),.wrusedw(),.rdusedw(fifo_count));
 assign O_ddr_user_wr_data=fifo_data[127:0];
 assign O_video_in_wr_busy=burst||O_ddr_user_wr_en;
 always @(posedge I_ddr_clk or negedge I_rst_n) begin
  if(!I_rst_n) begin burst<=0;burst_count<=0;burst_words<=240;drain_wait<=0;O_ddr_user_wr_en<=0;end
  else begin
   O_ddr_user_wr_en<=fifo_read;
   if(burst||fifo_empty)drain_wait<=0;
   else if(drain_wait!=1023)drain_wait<=drain_wait+1'b1;
   if(fifo_read) begin
    if(burst_count+1'b1==burst_words) begin burst<=0;burst_count<=0;end
    else burst_count<=burst_count+1'b1;
   end else if(!burst&&!O_ddr_user_wr_en&&!I_video_out_rd_busy&&!fifo_empty&&
               (fifo_count>=240||drain_wait==1023))begin
    burst<=1;burst_words<=fifo_count>=240?8'd240:fifo_count[7:0];drain_wait<=0;
   end
  end
 end
 reg [1:0] next_slot,write_slot;
 reg [17:0] written;
 reg frame_open;
 reg [24:0] write_addr;
 reg [1:0] chosen,try_slot;
 reg found;
 integer k;
 assign O_ingress_sof=admit&&source_sof;
 assign O_write_sof=O_ddr_user_wr_en&&fifo_data[128];
 assign O_write_slot=chosen;
 assign O_write_commit=O_ddr_user_wr_en&&fifo_data[129]&&!fifo_data[128]&&frame_open&&written==FRAME_WORDS-1&&!I_display_pause;
 assign O_commit_slot=write_slot;
 always @* begin
  chosen=next_slot;try_slot=0;found=0;
  for(k=0;k<4;k=k+1) begin
   try_slot=next_slot+k;
   if(!found&&(!I_display_valid||try_slot!=I_display_rp)&&
      (!O_frame_ready||try_slot!=O_video_out_rp)&&
      (!I_pending_valid||try_slot!=I_pending_rp)) begin chosen=try_slot;found=1;end
  end
 end
 // fifo_data and the registered write enable are aligned by the FIFO RAM.
 assign O_ddr_user_addr=fifo_data[128]?base(chosen):write_addr;
 always @(posedge I_ddr_clk or negedge I_rst_n) begin
  if(!I_rst_n) begin
   next_slot<=0;write_slot<=0;written<=0;frame_open<=0;
   write_addr<=0;O_video_out_rp<=0;O_frame_ready<=0;
  end else if(O_ddr_user_wr_en) begin
   if(fifo_data[128]) begin
    write_slot<=chosen;next_slot<=chosen+1'b1;written<=1;
    write_addr<=base(chosen)+25'd8;frame_open<=1;
   end else begin
    write_addr<=write_addr+25'd8;
    if(frame_open) begin
     if(fifo_data[129]||written==FRAME_WORDS-1) begin
      frame_open<=0;written<=0;
      if(fifo_data[129]&&written==FRAME_WORDS-1&&!I_display_pause) begin
       O_video_out_rp<=write_slot;O_frame_ready<=1;
      end
     end else written<=written+1'b1;
    end
   end
  end
 end
endmodule

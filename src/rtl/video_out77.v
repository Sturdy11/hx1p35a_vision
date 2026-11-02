module video_out77 # (parameter FRAME_WORDS=172800)(
 input wire I_rst_n,I_ddr_clk,
 output wire O_video_out_rd_busy,input wire I_video_in_wr_busy,
 input wire [1:0] I_video_out_rp,input wire I_frame_ready,
 output wire O_display_commit,output wire [1:0] O_display_slot,output wire O_display_valid,
 output reg [1:0] O_active_rp,output reg O_active_valid,
 output wire [1:0] O_pending_rp,output wire O_pending_valid,
 output wire O_ddr_user_rd_en,output reg [24:0] O_ddr_user_addr,
 input wire I_ddr_user_ready,I_ddr_user_rd_valid,
 input wire [127:0] I_ddr_user_rd_data,
 input wire I_dsi_clk,I_video_vsync,I_video_rd_en,
 output reg [23:0] O_vdieo_data,
 output wire [3:0] O_und_cnt,O_stall_cnt
);
 function [24:0] base;input [1:0] p;begin
  case(p) 0:base=0;1:base=7000000;2:base=14000000;3:base=21000000;endcase
 end endfunction
 reg [2:0] vsync_sync;
 wire S_video_frame_start=vsync_sync[1]&&!vsync_sync[2];
 always @(posedge I_ddr_clk or negedge I_rst_n) begin
  if(!I_rst_n) vsync_sync<=0;
  else vsync_sync<={vsync_sync[1:0],I_video_vsync};
 end
 reg frame_pending,S_fifo_rst;
 reg [3:0] reset_count;
 reg [1:0] pending_rp;
 reg pending_valid;
 assign O_pending_rp=pending_rp;
 assign O_pending_valid=frame_pending&&pending_valid;
 reg [9:0] outstanding;
 assign O_display_commit=frame_pending&&outstanding==0&&!S_video_frame_start;
 assign O_display_slot=pending_rp;assign O_display_valid=pending_valid;
 reg [17:0] issued;
 reg S_ddr_rd_valid;
 reg [7:0] S_ddr_rd_cnt;
 wire [8:0] S_fifo_wr_num;
 wire [127:0] S_fifo_rd_data;
 wire S_fifo_emtpy,S_fifo_rd_en,S_fifo_underflow;
 wire response=I_ddr_user_rd_valid&&(outstanding!=0);
 wire [10:0] reserved={2'b0,S_fifo_wr_num}+{1'b0,outstanding};
 wire S_ddr_rd_trig=I_rst_n&&O_active_valid&&!frame_pending&&!S_video_frame_start&&
  !S_fifo_rst&&!S_ddr_rd_valid&&!I_video_in_wr_busy&&issued<FRAME_WORDS&&reserved<=271;
 assign O_ddr_user_rd_en=S_ddr_rd_valid&&I_ddr_user_ready&&!frame_pending&&
  !S_video_frame_start&&!S_fifo_rst;
 assign O_video_out_rd_busy=S_ddr_rd_trig||S_ddr_rd_valid;
 always @(posedge I_ddr_clk or negedge I_rst_n) begin
  if(!I_rst_n) outstanding<=0;
  else case({O_ddr_user_rd_en,response})
   2'b10:outstanding<=outstanding+1'b1;
   2'b01:outstanding<=outstanding-1'b1;
   default:outstanding<=outstanding;
  endcase
 end

 // discarded first; they must never enter the next frame's FIFO.
 always @(posedge I_ddr_clk or negedge I_rst_n) begin
  if(!I_rst_n) begin
   frame_pending<=0;S_fifo_rst<=1;reset_count<=0;pending_rp<=0;pending_valid<=0;
   O_active_rp<=0;O_active_valid<=0;O_ddr_user_addr<=0;issued<=0;
   S_ddr_rd_valid<=0;S_ddr_rd_cnt<=0;
  end else if(S_video_frame_start) begin
   frame_pending<=1;pending_rp<=I_video_out_rp;pending_valid<=I_frame_ready;
   S_ddr_rd_valid<=0;S_ddr_rd_cnt<=0;
  end else if(frame_pending) begin
   if(outstanding==0) begin
    frame_pending<=0;S_fifo_rst<=1;reset_count<=0;
    O_active_rp<=pending_rp;O_ddr_user_addr<=base(pending_rp);issued<=0;
    O_active_valid<=pending_valid;
   end
  end else if(S_fifo_rst) begin
   if(reset_count==10) begin S_fifo_rst<=0;reset_count<=0;end
   else reset_count<=reset_count+1'b1;
  end else begin
   if(S_ddr_rd_trig) begin S_ddr_rd_valid<=1;S_ddr_rd_cnt<=0;end
   if(O_ddr_user_rd_en) begin
    issued<=issued+1'b1;O_ddr_user_addr<=O_ddr_user_addr+25'd8;
    if(S_ddr_rd_cnt==239) begin S_ddr_rd_valid<=0;S_ddr_rd_cnt<=0;end
    else S_ddr_rd_cnt<=S_ddr_rd_cnt+1'b1;
   end
  end
 end
 w128_d512_fifo U_w128_d512_fifo(
  .rst(!I_rst_n||S_fifo_rst),.clkw(I_ddr_clk),
  .we(response&&!frame_pending&&!S_video_frame_start&&!S_fifo_rst),.di(I_ddr_user_rd_data),
  .wrusedw(S_fifo_wr_num),.afull(),.full_flag(),
  .clkr(I_dsi_clk),.re(S_fifo_rd_en),.dout(S_fifo_rd_data),
  .rdusedw(),.valid(),.empty_flag(S_fifo_emtpy),.aempty());
 reg [1:0] active_pix;
 reg [3:0] S_und_cnt,S_stall_cnt;
 reg [3:0] S_fifo_rd_cnt,S_fifo_rd_cnt_1d;
 reg S_video_rd_en_1d,S_fifo_hold_1d;
 reg [127:0] S_fifo_rd_data_1d;
 reg [23:0] S_last_video_pixel;
 assign O_und_cnt=S_und_cnt;
 assign O_stall_cnt=S_stall_cnt;
 always @(posedge I_dsi_clk or negedge I_rst_n) begin
  if(!I_rst_n) begin active_pix<=0;S_und_cnt<=0;end
  else begin
   active_pix<={active_pix[0],O_active_valid};
   if(S_fifo_underflow&&S_und_cnt!=15) S_und_cnt<=S_und_cnt+1'b1;
  end
 end
 always @(posedge I_ddr_clk or negedge I_rst_n) begin
  if(!I_rst_n) S_stall_cnt<=0;
  else if(S_ddr_rd_valid&&!I_ddr_user_ready&&S_stall_cnt!=15) S_stall_cnt<=S_stall_cnt+1'b1;
 end
   wire S_fifo_rd_req = I_video_rd_en && active_pix[1] &&
                        ((S_fifo_rd_cnt == 'd0) ||
                         (S_fifo_rd_cnt == 'd5) ||
                         (S_fifo_rd_cnt == 'd10));
   // Empty is only an underflow when a new 128-bit word is requested.  While

   assign S_fifo_underflow = S_fifo_rd_req && S_fifo_emtpy;

   always @(posedge I_dsi_clk or negedge I_rst_n) begin
       if(!I_rst_n)
           S_fifo_rd_cnt <= 4'd0;
       else if(!I_video_rd_en)
           S_fifo_rd_cnt <= 4'd0;
       else if(S_fifo_underflow)
           S_fifo_rd_cnt <= S_fifo_rd_cnt;
       else
           S_fifo_rd_cnt <= S_fifo_rd_cnt + 4'd1;
   end

   // Never advance the FIFO read pointer while it is empty.  The serializer
   // below repeats S_last_video_pixel during the same short underflow gap.
   assign S_fifo_rd_en = S_fifo_rd_req && !S_fifo_emtpy;

   always @(posedge I_dsi_clk or negedge I_rst_n) begin
       if(!I_rst_n) begin
           S_video_rd_en_1d  <= 1'b0;
           S_fifo_rd_cnt_1d  <= 4'd0;
           S_fifo_rd_data_1d <= 128'd0;
           S_fifo_hold_1d   <= 1'b0;
       end else begin
           S_video_rd_en_1d  <= I_video_rd_en;
           S_fifo_rd_cnt_1d  <= S_fifo_rd_cnt;
           S_fifo_rd_data_1d <= S_fifo_rd_data;
           S_fifo_hold_1d   <= S_fifo_underflow;
       end
   end

   always @(posedge I_dsi_clk or negedge I_rst_n) begin
       if(!I_rst_n) begin
           O_vdieo_data     <= 24'd0;
           S_last_video_pixel <= 24'd0;
       end else if(S_video_rd_en_1d)
           begin
               if(S_fifo_hold_1d)
                   O_vdieo_data <= S_last_video_pixel;
               else begin
                   case(S_fifo_rd_cnt_1d)
                       'd0: O_vdieo_data  <= S_fifo_rd_data[127:104];
                       'd1: O_vdieo_data  <= S_fifo_rd_data[103:80];
                       'd2: O_vdieo_data  <= S_fifo_rd_data[79:56];
                       'd3: O_vdieo_data  <= S_fifo_rd_data[55:32];
                       'd4: O_vdieo_data  <= S_fifo_rd_data[31:8];
                       'd5: O_vdieo_data  <= {S_fifo_rd_data_1d[7:0],S_fifo_rd_data[127:112]};
                       'd6: O_vdieo_data  <= S_fifo_rd_data[111:88];
                       'd7: O_vdieo_data  <= S_fifo_rd_data[87:64];
                       'd8: O_vdieo_data  <= S_fifo_rd_data[63:40];
                       'd9: O_vdieo_data  <= S_fifo_rd_data[39:16];
                       'd10: O_vdieo_data <= {S_fifo_rd_data_1d[15:0],S_fifo_rd_data[127:120]};
                       'd11: O_vdieo_data <= S_fifo_rd_data[119:96];
                       'd12: O_vdieo_data <= S_fifo_rd_data[95:72];
                       'd13: O_vdieo_data <= S_fifo_rd_data[71:48];
                       'd14: O_vdieo_data <= S_fifo_rd_data[47:24];
                       'd15: O_vdieo_data <= S_fifo_rd_data[23:0];
                   endcase

                   S_last_video_pixel <= O_vdieo_data;
               end
           end
       else
           O_vdieo_data <= 'd0;
   end

endmodule

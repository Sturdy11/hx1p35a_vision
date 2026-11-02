module awb82 #(parameter IMG_HEIGHT=720,IMG_WIDTH=1280,MIN_NEUTRAL=64)(
 input wire I_clk,I_rst_n,I_tlast,I_tuser,input wire [95:0] I_tdata,input wire I_tvalid,
 output wire I_tready,output wire O_tlast,O_tuser,output wire [95:0] O_tdata,
 output wire O_tvalid,input wire O_tready,
 output reg [7:0] O_meter_mean,O_meter_target,output reg O_meter_valid,O_meter_toggle,
 output wire O_wb_stable,output reg [11:0] gain_r,gain_b
);
 localparam WORDS=IMG_WIDTH*IMG_HEIGHT/4;
 assign I_tready=O_tready;
 reg [3:0] phase;reg sample_d;reg [7:0] raw_r,raw_b;
 reg [19:0] pr[0:3],pb[0:3];reg [7:0] pg[0:3];reg v0,u0,l0,v1,u1,l1;reg [95:0] rgb1;
 reg [19:0] words;
 reg [23:0] sr,sg,sb,br,bg,bb,mb,sa;reg [15:0] nw,nb,nbw,na;
 reg [7:0] peak,minimum,peak_ref;
 wire [7:0] threshold=(peak_ref>>1)<32?8'd32:(peak_ref>>1);
 wire [7:0] cr=(|pr[0][19:16])?8'hff:pr[0][15:8],cg=pg[0],cb=(|pb[0][19:16])?8'hff:pb[0][15:8];
 wire [7:0] mx0=cr>cg?cr:cg,mx=mx0>cb?mx0:cb,mn0=cr<cg?cr:cg,mn=mn0<cb?mn0:cb;
 wire [8:0] chroma={1'b0,mx}-{1'b0,mn};
 wire signed [10:0] ex=$signed({2'b0,cg,1'b0})-$signed({3'b0,cr})-$signed({3'b0,cb});
 wire signed [15:0] ex16=$signed({{5{ex[10]}},ex})<<<4;
 wire [9:0] sum={2'b0,cr}+{2'b0,cg}+{2'b0,cb};
 wire green=({1'b0,cg}>{1'b0,cr}+9'd4)&&({1'b0,cg}>{1'b0,cb}+9'd2)&&(ex16>$signed({6'd0,sum}));
 wire bright=cg>=threshold;
 wire wb_bright=bright&&cg<248&&raw_r<248&&raw_b<248;
 // Saturation introduced by the current WB coefficient is not sensor clipping.

 wire neutral=bright&&!green&&mn>=32&&chroma<=({1'b0,mx}>>1)&&cg<248&&raw_r<248&&raw_b<248;
 reg [23:0] fr,fg,fb,fm;reg [15:0] fc;
 reg frame_ok,reference_ok,meter_reference,candidate_ready,candidate_acquire,calibrated;
 reg [11:0] candidate_r,candidate_b;reg [2:0] state;
 reg div_start;reg [31:0] div_num;reg [23:0] div_den;wire div_busy,div_done;wire [31:0] div_q;
 frame_div81 divider(.clk(I_clk),.rst_n(I_rst_n),.start(div_start),.numerator(div_num),.denominator(div_den),.busy(div_busy),.done(div_done),.quotient(div_q));
 function [11:0] clamp_gain;input [31:0] value;begin

  clamp_gain=value<128?128:value>4095?4095:value[11:0];
 end endfunction
 function [11:0] slew;input [11:0] oldv,newv;reg [12:0] step;begin
  step=oldv>>5;if(step<4)step=4;
  slew={1'b0,newv}>{1'b0,oldv}+step?oldv+step:{1'b0,oldv}>{1'b0,newv}+step?oldv-step:newv;
 end endfunction
 wire [11:0] next_r=candidate_acquire?candidate_r:slew(gain_r,candidate_r),next_b=candidate_acquire?candidate_b:slew(gain_b,candidate_b);
 wire [11:0] use_r=I_tuser&&candidate_ready?next_r:gain_r,use_b=I_tuser&&candidate_ready?next_b:gain_b;
 wire [12:0] band_r=(gain_r>>4)<8?13'd8:(gain_r>>4),band_b=(gain_b>>4)<8?13'd8:(gain_b>>4);
 assign O_wb_stable=calibrated&&candidate_ready&&({1'b0,gain_r}<={1'b0,candidate_r}+band_r)&&({1'b0,candidate_r}<={1'b0,gain_r}+band_r)&&
                    ({1'b0,gain_b}<={1'b0,candidate_b}+band_b)&&({1'b0,candidate_b}<={1'b0,gain_b}+band_b);
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin phase<=0;sample_d<=0;raw_r<=0;raw_b<=0;end
  else begin
   if(I_tuser)phase<=I_tvalid?1:0;else if(I_tvalid)phase<=phase+1'b1;
   sample_d<=I_tvalid&&((I_tuser?4'd0:phase)==0);raw_r<=I_tdata[23:16];raw_b<=I_tdata[7:0];
  end
 end
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin gain_r<=256;gain_b<=256;calibrated<=0;end
  else if(I_tuser&&candidate_ready)begin gain_r<=next_r;gain_b<=next_b;if(candidate_acquire)calibrated<=1;end
 end
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin
   words<=0;sr<=0;sg<=0;sb<=0;br<=0;bg<=0;bb<=0;mb<=0;sa<=0;nw<=0;nb<=0;nbw<=0;na<=0;peak<=0;minimum<=255;peak_ref<=64;
   fr<=0;fg<=0;fb<=0;fm<=0;fc<=0;frame_ok<=0;reference_ok<=0;meter_reference<=0;candidate_ready<=0;candidate_acquire<=0;
   candidate_r<=256;candidate_b<=256;state<=0;div_start<=0;div_num<=0;div_den<=0;
   O_meter_mean<=0;O_meter_target<=176;O_meter_valid<=0;O_meter_toggle<=0;
  end else begin
   div_start<=0;

   if(u0)begin
    fr<=calibrated&&nw>=MIN_NEUTRAL?sr:br;fg<=calibrated&&nw>=MIN_NEUTRAL?sg:bg;fb<=calibrated&&nw>=MIN_NEUTRAL?sb:bb;
    reference_ok<=nbw>=MIN_NEUTRAL&&peak>=32&&{1'b0,peak}>={1'b0,minimum}+9'd24&&br!=0&&bb!=0;
    meter_reference<=nb>=MIN_NEUTRAL&&{1'b0,peak}>={1'b0,minimum}+9'd24;
    fm<=nb>=MIN_NEUTRAL&&{1'b0,peak}>={1'b0,minimum}+9'd24 ? mb:sa;
    fc<=nb>=MIN_NEUTRAL&&{1'b0,peak}>={1'b0,minimum}+9'd24 ? nb:na;
    frame_ok<=words>=WORDS-WORDS/16&&words<=WORDS+WORDS/16&&na!=0;peak_ref<=peak;
    words<=v0?1:0;peak<=sample_d?cg:0;minimum<=sample_d?cg:255;
    sr<=sample_d&&neutral?raw_r:0;sg<=sample_d&&neutral?cg:0;sb<=sample_d&&neutral?raw_b:0;nw<=sample_d&&neutral?1:0;
    br<=sample_d&&wb_bright?raw_r:0;bg<=sample_d&&wb_bright?cg:0;bb<=sample_d&&wb_bright?raw_b:0;nbw<=sample_d&&wb_bright?1:0;
    mb<=sample_d&&bright?cg:0;nb<=sample_d&&bright?1:0;
    sa<=sample_d?cg:0;na<=sample_d?1:0;state<=1;
   end else begin
    if(v0)begin
     words<=words+1'b1;
     if(sample_d)begin
      sa<=sa+cg;na<=na+1'b1;if(cg>peak)peak<=cg;if(cg<minimum)minimum<=cg;
      if(bright)begin mb<=mb+cg;nb<=nb+1'b1;end
      if(wb_bright)begin br<=br+raw_r;bg<=bg+cg;bb<=bb+raw_b;nbw<=nbw+1'b1;end
      if(neutral)begin sr<=sr+raw_r;sg<=sg+cg;sb<=sb+raw_b;nw<=nw+1'b1;end
     end
    end
    case(state)
     1:if(!div_busy)begin
      if(!frame_ok)begin O_meter_valid<=0;O_meter_toggle<=~O_meter_toggle;state<=0;end
      else if(reference_ok)begin div_num<={fg,8'd0};div_den<=fr;div_start<=1;state<=2;candidate_acquire<=!calibrated;end
      else begin candidate_r<=gain_r;candidate_b<=gain_b;candidate_ready<=calibrated;candidate_acquire<=0;state<=4;end
     end
     2:if(div_done)begin candidate_r<=clamp_gain(div_q);div_num<={fg,8'd0};div_den<=fb;div_start<=1;state<=3;end
     3:if(div_done)begin candidate_b<=clamp_gain(div_q);candidate_ready<=1;state<=4;end
     4:if(!div_busy)begin div_num<={8'd0,fm};div_den<={8'd0,fc};div_start<=1;state<=5;end
     5:if(div_done)begin O_meter_mean<=div_q>255?255:div_q[7:0];O_meter_target<=meter_reference?176:48;O_meter_valid<=1;O_meter_toggle<=~O_meter_toggle;state<=0;end
    endcase
   end
  end
 end
 integer k;
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin
   v0<=0;u0<=0;l0<=0;v1<=0;u1<=0;l1<=0;rgb1<=0;
   for(k=0;k<4;k=k+1)begin pr[k]<=0;pb[k]<=0;pg[k]<=0;end
  end else begin
   v0<=I_tvalid;u0<=I_tuser;l0<=I_tlast;v1<=v0;u1<=u0;l1<=l0;
   for(k=0;k<4;k=k+1)begin
    pr[k]<=I_tdata[k*24+16+:8]*use_r;pb[k]<=I_tdata[k*24+:8]*use_b;pg[k]<=I_tdata[k*24+8+:8];
    rgb1[k*24+:24]<={(|pr[k][19:16])?8'hff:pr[k][15:8],pg[k],(|pb[k][19:16])?8'hff:pb[k][15:8]};
   end
  end
 end
 assign O_tvalid=v1;assign O_tuser=u1;assign O_tlast=l1;assign O_tdata=rgb1;
endmodule

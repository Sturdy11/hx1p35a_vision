// two synchronous RAMs, frame-atomic ratio maps. No pixel backpressure or DSP.
module local_light85 #(
 parameter MIN_SAMPLES=32,MIN_GLOBAL_SAMPLES=256,
 parameter WHITE_LEVEL=100,SEED_LEVEL=48,CORE_LEVEL=64,
 parameter FG_FLOOR=12,WHITE_FLOOR=60,SEED_FLOOR=28,CORE_FLOOR=36
)(
 input wire clk,rst_n,enable,valid,
 input wire [11:0] x,y,input wire [7:0] base_level,
 input wire capture_start,capture_end,sample_valid,input wire [7:0] sample_green,
 output wire [7:0] fg_level,white_level,seed_level,core_level,
 output wire ready,output wire meter_busy,output reg [15:0] map_sequence
);
 localparam INIT=0,IDLE=1,CLEAR=2,COLLECT=3,RWAIT1=4,RWAIT2=5,RWRITE=6,
 GLOBAL_START=7,DIVIDE=8,DIV_DONE=9,TILE_REQ=10,TILE_WAIT1=11,TILE_WAIT2=12,
 MEAN_WRITE=13,RATIO_START=14,OLD_REQ=15,OLD_WAIT1=16,OLD_WAIT2=17,MAP_WRITE=18;
 reg [4:0] state;
 reg [6:0] init_index;
 reg [5:0] tile_index,stat_addr;
 reg [7:0] sample_g;
 reg [21:0] global_sum;
 reg [13:0] global_count;
 reg [7:0] global_mean;
 reg global_good,end_pending,start_pending;
 reg active_bank,write_bank,map_pending,initialized;
 (* ram_style="block" *) reg [25:0] stats_mem[0:63];
 (* ram_style="block" *) reg [4:0] map_mem[0:127];
 reg [25:0] stats_q;
 reg [4:0] old_map_q,cache_map_q;
 reg [6:0] old_addr,cache_addr;
 reg [4:0] target_ratio,next_ratio;
 reg tile_good;
 reg [21:0] dividend,quotient;
 reg [14:0] remainder;
 reg [13:0] divisor;
 reg [4:0] div_bits;
 reg [1:0] div_kind;
 wire [15:0] trial={remainder,dividend[21]};
 wire subtract_ok=trial>={2'b0,divisor};
 wire [21:0] quotient_next={quotient[20:0],subtract_ok};
 wire frame_start=valid&&x==0&&y==0;
 wire [2:0] tile_x=x<160?0:x<320?1:x<480?2:x<640?3:x<800?4:x<960?5:x<1120?6:7;
 wire [2:0] tile_y=y<120?0:y<240?1:y<360?2:y<480?3:y<600?4:5;
 wire stat_we=state==CLEAR||state==RWRITE||state==MEAN_WRITE;
 wire [25:0] stat_data=state==CLEAR?26'd0:
     state==MEAN_WRITE?{17'd0,tile_good,global_mean}:
     {stats_q[25:17]+9'd1,stats_q[16:0]+{9'd0,sample_g}};
 wire map_we=state==INIT||state==MAP_WRITE;
 wire [6:0] map_write_addr=state==INIT?init_index:{write_bank,tile_index};
 wire [4:0] map_write_data=state==INIT?5'd16:next_ratio;
 wire [6:0] calc_map_addr=map_we?map_write_addr:old_addr;

 always @(posedge clk)begin
  stats_q<=stats_mem[stat_addr];
  if(stat_we)stats_mem[stat_addr]<=stat_data;
  old_map_q<=map_mem[calc_map_addr];
  cache_map_q<=map_mem[cache_addr];
  if(map_we)map_mem[calc_map_addr]<=map_write_data;
 end
 assign meter_busy=state!=IDLE&&state!=COLLECT;
 reg [7:0] tile_mean;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=INIT;init_index<=0;tile_index<=0;stat_addr<=0;sample_g<=0;
   global_sum<=0;global_count<=0;global_mean<=0;global_good<=0;end_pending<=0;start_pending<=0;
   active_bank<=0;write_bank<=1;map_pending<=0;initialized<=0;map_sequence<=0;
   old_addr<=0;target_ratio<=16;next_ratio<=16;tile_good<=0;tile_mean<=0;
   dividend<=0;quotient<=0;remainder<=0;divisor<=1;div_bits<=0;div_kind<=0;
  end else if(!enable)begin
   state<=INIT;init_index<=0;initialized<=0;active_bank<=0;write_bank<=1;
   map_pending<=0;map_sequence<=0;global_sum<=0;global_count<=0;end_pending<=0;start_pending<=0;
  end else begin
   if(frame_start&&map_pending)begin active_bank<=write_bank;map_pending<=0;map_sequence<=map_sequence+1'b1;end
   if(capture_end)end_pending<=1;
   if(capture_start&&state==INIT)start_pending<=1;
   case(state)
    INIT:if(init_index==127)begin initialized<=1;state<=IDLE;end else init_index<=init_index+1'b1;
    IDLE:if(capture_start)begin
     tile_index<=0;stat_addr<=0;global_sum<=0;global_count<=0;end_pending<=0;state<=CLEAR;
    end
    CLEAR:if(tile_index==47)begin state<=COLLECT;end
     else begin tile_index<=tile_index+1'b1;stat_addr<=stat_addr+1'b1;end
    COLLECT:if(end_pending||capture_end)begin state<=GLOBAL_START;end
     else if(sample_valid)begin
      stat_addr<={tile_y,tile_x};sample_g<=sample_green;
      global_sum<=global_sum+sample_green;global_count<=global_count+1'b1;state<=RWAIT1;
     end
    RWAIT1:state<=RWAIT2;
    RWAIT2:state<=RWRITE;
    RWRITE:state<=COLLECT;
    GLOBAL_START:begin
     global_good<=global_count>=MIN_GLOBAL_SAMPLES;
     if(global_count>=MIN_GLOBAL_SAMPLES)begin
      dividend<=global_sum;divisor<=global_count;remainder<=0;quotient<=0;div_bits<=22;div_kind<=0;state<=DIVIDE;
     end else begin global_mean<=0;tile_index<=0;write_bank<=!active_bank;state<=TILE_REQ;end
    end
    DIVIDE:begin
     remainder<=subtract_ok?trial-{2'b0,divisor}:trial[14:0];
     dividend<={dividend[20:0],1'b0};quotient<=quotient_next;
     if(div_bits==1)state<=DIV_DONE;else div_bits<=div_bits-1'b1;
    end
    DIV_DONE:case(div_kind)
     0:begin global_mean<=quotient>255?8'd255:quotient[7:0];tile_index<=0;write_bank<=!active_bank;state<=TILE_REQ;end
     1:begin tile_mean<=quotient>255?8'd255:quotient[7:0];state<=RATIO_START;end
     default:begin target_ratio<=quotient<8?5'd8:quotient>16?5'd16:quotient[4:0];state<=OLD_REQ;end
    endcase
    TILE_REQ:begin stat_addr<=tile_index;state<=TILE_WAIT1;end
    TILE_WAIT1:state<=TILE_WAIT2;
    TILE_WAIT2:begin
     tile_good<=global_good&&global_mean!=0&&stats_q[25:17]>=MIN_SAMPLES;
     if(global_good&&global_mean!=0&&stats_q[25:17]>=MIN_SAMPLES)begin
      dividend<={5'd0,stats_q[16:0]};divisor<={5'd0,stats_q[25:17]};
      remainder<=0;quotient<=0;div_bits<=22;div_kind<=1;state<=DIVIDE;
     end else begin target_ratio<=16;state<=OLD_REQ;end
    end
    RATIO_START:begin
     dividend<={10'd0,tile_mean,4'b0};divisor<={6'd0,global_mean};
     remainder<=0;quotient<=0;div_bits<=22;div_kind<=2;state<=DIVIDE;
    end
    OLD_REQ:begin old_addr<={active_bank,tile_index};state<=OLD_WAIT1;end
    OLD_WAIT1:state<=OLD_WAIT2;
    OLD_WAIT2:begin

     if(!tile_good)next_ratio<=old_map_q;
     else if(target_ratio>old_map_q)next_ratio<=old_map_q+1'b1;
     else if(target_ratio<old_map_q)next_ratio<=old_map_q-1'b1;
     else next_ratio<=old_map_q;
     state<=MAP_WRITE;
    end
    MAP_WRITE:if(tile_index==47)begin map_pending<=1;end_pending<=0;state<=IDLE;end
     else begin tile_index<=tile_index+1'b1;state<=TILE_REQ;end
    default:state<=INIT;
   endcase

   if((capture_start||start_pending)&&state==INIT&&init_index==127)begin
    tile_index<=0;stat_addr<=0;global_sum<=0;global_count<=0;end_pending<=0;start_pending<=0;state<=CLEAR;
   end
  end
 end

 localparam C_IDLE=0,C_REQ=1,C_WAIT1=2,C_WAIT2=3,C_MUL=4,C_STORE=5;
 reg [2:0] cstate,crow,ccol;
 reg cbank;reg [7:0] frame_level;
 reg [4:0] ratio_shift,ratio_value;
 reg [12:0] product,multiplicand;
 reg [2:0] bit_index;
 reg [31:0] row_cache[0:7];reg [7:0] row_valid;
 reg [31:0] current_thresholds;reg current_valid;
 integer k;
 function [7:0] scale;
  input [7:0] value;input [4:0] ratio;input [7:0] floor_value;
  reg [12:0] t;integer j;
  begin t=0;for(j=0;j<5;j=j+1)if(ratio[j])t=t+({5'd0,value}<<j);
   scale=(t>>4)<floor_value?floor_value:(t>>4);end
 endfunction
 wire next_strip=valid&&x==1279&&(y==119||y==239||y==359||y==479||y==599);
 wire [7:0] cache_fg=(product>>4)<FG_FLOOR?FG_FLOOR:(product>>4);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   cstate<=C_IDLE;crow<=0;ccol<=0;cbank<=0;frame_level<=20;cache_addr<=0;
   ratio_shift<=16;ratio_value<=16;product<=0;multiplicand<=0;bit_index<=0;
   row_valid<=0;current_thresholds<={8'd20,8'd100,8'd48,8'd64};current_valid<=0;
   for(k=0;k<8;k=k+1)row_cache[k]<=0;
  end else if(!enable)begin cstate<=C_IDLE;row_valid<=0;current_valid<=0;end
  else begin
   case(cstate)
    C_REQ:begin cache_addr<={cbank,crow,ccol};cstate<=C_WAIT1;end
    C_WAIT1:cstate<=C_WAIT2;
    C_WAIT2:begin ratio_shift<=cache_map_q;ratio_value<=cache_map_q;product<=0;multiplicand<={5'd0,frame_level};bit_index<=0;cstate<=C_MUL;end
    C_MUL:begin
     if(ratio_shift[0])product<=product+multiplicand;
     multiplicand<=multiplicand<<1;ratio_shift<=ratio_shift>>1;
     if(bit_index==4)cstate<=C_STORE;else bit_index<=bit_index+1'b1;
    end
    C_STORE:begin
     row_cache[ccol]<={cache_fg,
       scale(WHITE_LEVEL,ratio_value,WHITE_FLOOR),scale(SEED_LEVEL,ratio_value,SEED_FLOOR),scale(CORE_LEVEL,ratio_value,CORE_FLOOR)};
     row_valid[ccol]<=1;
     if(ccol==7)cstate<=C_IDLE;else begin ccol<=ccol+1'b1;cstate<=C_REQ;end
    end
    default:cstate<=C_IDLE;
   endcase
   if(frame_start)begin
    frame_level<=base_level;crow<=0;ccol<=0;cbank<=map_pending?write_bank:active_bank;
    row_valid<=0;current_valid<=0;cstate<=initialized?C_REQ:C_IDLE;
   end else if(next_strip)begin crow<=tile_y+1'b1;ccol<=0;cbank<=active_bank;row_valid<=0;current_valid<=0;cstate<=C_REQ;end
   if(valid)case(x)
    12:begin current_thresholds<=row_cache[0];current_valid<=row_valid[0];end
    159:begin current_thresholds<=row_cache[1];current_valid<=row_valid[1];end
    319:begin current_thresholds<=row_cache[2];current_valid<=row_valid[2];end
    479:begin current_thresholds<=row_cache[3];current_valid<=row_valid[3];end
    639:begin current_thresholds<=row_cache[4];current_valid<=row_valid[4];end
    799:begin current_thresholds<=row_cache[5];current_valid<=row_valid[5];end
    959:begin current_thresholds<=row_cache[6];current_valid<=row_valid[6];end
    1119:begin current_thresholds<=row_cache[7];current_valid<=row_valid[7];end
   endcase
  end
 end
 assign ready=initialized&&current_valid;
 assign fg_level=ready?current_thresholds[31:24]:base_level;
 assign white_level=ready?current_thresholds[23:16]:WHITE_LEVEL;
 assign seed_level=ready?current_thresholds[15:8]:SEED_LEVEL;
 assign core_level=ready?current_thresholds[7:0]:CORE_LEVEL;
endmodule

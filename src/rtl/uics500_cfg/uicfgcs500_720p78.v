`timescale 1ns/1ns

module uicfgcs500_720p78 #(
 parameter CLK_DIV=239,RETRIES=2,TX_TIMEOUT=(CLK_DIV+1)*128
)(
 input wire I_clk,I_rst_n,I_ae_req,input wire [15:0] I_ae,I_ag,
 output wire O_cam_scl,inout wire IO_cam_sda,
 output reg O_cfg_done,O_ae_cfg_done,O_cfg_error
);
 localparam IDLE=0,REQUEST=1,WAIT_BUSY=2,WAIT_DONE=3,RETRY=4,FAILED=5;
 reg [2:0] state;
 reg [7:0] rst_cnt=0;
 reg iic_req,failed_tx;reg [31:0] wr_data;
 reg [8:0] reg_index;reg [17:0] delay_cnt;
 reg [23:0] timer;reg [1:0] retry_count;
 wire iic_busy,iic_error;
 wire [23:0] init_data,ae_data;
 wire [8:0] init_size,ae_size;
 wire [23:0] selected_data=O_cfg_done?ae_data:init_data;
 wire [15:0] gain_value;
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)rst_cnt<=0;
  else if(!rst_cnt[7])rst_cnt<=rst_cnt+1'b1;
 end
 always @(posedge I_clk)begin
  if(!rst_cnt[7])begin
   state<=IDLE;reg_index<=0;iic_req<=0;wr_data<=0;O_cfg_done<=0;O_ae_cfg_done<=0;O_cfg_error<=0;
   delay_cnt<=0;timer<=0;retry_count<=0;failed_tx<=0;
  end else begin
   if((state==WAIT_BUSY||state==WAIT_DONE)&&iic_error)failed_tx<=1;
   case(state)
    IDLE:begin
     iic_req<=0;timer<=0;
     if(!O_cfg_done)begin
      if(reg_index==115&&delay_cnt<240000)delay_cnt<=delay_cnt+1'b1;
      else if(reg_index==init_size)begin O_cfg_done<=1;O_ae_cfg_done<=1;reg_index<=0;end
      else state<=REQUEST;
     end else if(I_ae_req)begin O_ae_cfg_done<=0;reg_index<=0;end
     else if(!O_ae_cfg_done)begin
      if(reg_index==ae_size)O_ae_cfg_done<=1;else state<=REQUEST;
     end
    end
    REQUEST:if(!iic_busy)begin
     wr_data<={selected_data[7:0],selected_data[15:8],selected_data[23:16],8'h6c};
     failed_tx<=0;timer<=0;iic_req<=1;state<=WAIT_BUSY;
    end
    WAIT_BUSY:begin
     timer<=timer+1'b1;
     if(iic_busy)begin iic_req<=0;timer<=0;state<=WAIT_DONE;end
     else if(timer==TX_TIMEOUT-1)begin iic_req<=0;O_cfg_error<=1;state<=FAILED;end
    end
    WAIT_DONE:begin
     timer<=timer+1'b1;
     if(!iic_busy)begin
      if(failed_tx||iic_error)begin
       if(retry_count<RETRIES)begin retry_count<=retry_count+1'b1;timer<=0;state<=RETRY;end
       else begin O_cfg_error<=1;state<=FAILED;end
      end else begin reg_index<=reg_index+1'b1;retry_count<=0;state<=IDLE;end
     end else if(timer==TX_TIMEOUT-1)begin O_cfg_error<=1;state<=FAILED;end
    end
    RETRY:begin
     timer<=timer+1'b1;
     if(timer==CLK_DIV*4+3)begin timer<=0;state<=REQUEST;end
    end
    FAILED:begin iic_req<=0;O_ae_cfg_done<=0;end
    default:begin iic_req<=0;O_cfg_error<=1;state<=FAILED;end
   endcase
  end
 end
 uii2c #(.WMEN_LEN(4),.RMEN_LEN(1),.CLK_DIV(CLK_DIV)) u_i2c(
 .I_clk(I_clk),.I_rstn(rst_cnt[7]),.O_iic_scl(O_cam_scl),.IO_iic_sda(IO_cam_sda),
 .I_wr_data(wr_data),.I_wr_cnt(8'd4),.O_rd_data(),.I_rd_cnt(8'd0),.I_iic_mode(1'b0),
 .I_iic_req(iic_req),.O_iic_busy(iic_busy),.O_iic_bus_error(iic_error),.IO_iic_sda_dg());
 uics500reg_720p60 u_init_table(.REG_INDEX(reg_index),.REG_DATA(init_data),.REG_SIZE(init_size));
 SC500GainTbl u_gain_table(.I_clk(I_clk),.I_rstn(rst_cnt[7]),.I(I_ag-16),.O(gain_value));
 uics500regAE u_ae_table(.REG_INDEX(reg_index),.REG_DATA(ae_data),.REG_SIZE(ae_size),.I_AG(gain_value),.I_AE(I_ae));
endmodule

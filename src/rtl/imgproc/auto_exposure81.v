// Exposure priority, complete-statistics CDC and one I2C write in flight.

module auto_exposure81 #(
 parameter AE_INIT=3990,AG_INIT=80,AE_MIN=200,AE_MAX=3990,AG_MIN=16,AG_MAX=89
)(
 input wire I_clk,I_rst_n,I_enable,I_cam_cfg_done,I_ae_cfg_done,
 input wire I_meter_toggle,I_meter_valid,input wire [7:0] I_meter_mean,I_meter_target,
 output reg O_ae_req,output reg [15:0] O_ae,O_ag,output wire O_allow_digital
);
 wire upd;wire [16:0] meter;
 cdc_bus_sync #(.W(17)) sync(.I_dst_clk(I_clk),.I_dst_rst_n(I_rst_n),.I_d({I_meter_valid,I_meter_mean,I_meter_target}),.I_toggle(I_meter_toggle),.O_q(meter),.O_upd(upd));
 reg [1:0] settle;reg waiting,saw_busy;
 wire [7:0] mean=meter[15:8],target=meter[7:0];
 wire [8:0] band=target<128?9'd4:9'd10,fast_band=target<128?9'd12:9'd32;
 wire too_bright={1'b0,mean}>{1'b0,target}+band,too_dark={1'b0,mean}+band<{1'b0,target};
 wire large_error=({1'b0,mean}>{1'b0,target}+fast_band)||({1'b0,mean}+fast_band<{1'b0,target});
 wire [15:0] step0=large_error?(O_ae>>3):(O_ae>>5),step=step0<8?16'd8:step0;
 assign O_allow_digital=I_cam_cfg_done&&O_ae>=AE_MAX&&O_ag>=AG_INIT;
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin O_ae<=AE_INIT;O_ag<=AG_INIT;O_ae_req<=0;settle<=2;waiting<=0;saw_busy<=0;end
  else begin
   O_ae_req<=0;
   if(waiting)begin
    if(!I_ae_cfg_done)saw_busy<=1;
    if(saw_busy&&I_ae_cfg_done)begin waiting<=0;saw_busy<=0;settle<=2;end
   end else if(upd&&I_enable&&I_cam_cfg_done&&I_ae_cfg_done&&meter[16])begin
    if(settle!=0)settle<=settle-1'b1;
    else if(too_bright||too_dark)begin
     if(too_bright)begin
      if(O_ae>AE_MIN)O_ae<=O_ae>AE_MIN+step?O_ae-step:AE_MIN;
      else if(O_ag>AG_MIN)O_ag<=O_ag-1'b1;
     end else begin
      if(O_ae<AE_MAX)O_ae<=O_ae+step>AE_MAX?AE_MAX:O_ae+step;
      else if(O_ag<AG_MAX)O_ag<=O_ag+1'b1;
     end
     if((too_bright&&(O_ae>AE_MIN||O_ag>AG_MIN))||(too_dark&&(O_ae<AE_MAX||O_ag<AG_MAX)))begin
      O_ae_req<=1;waiting<=1;saw_busy<=0;
     end
    end
   end
  end
 end
endmodule

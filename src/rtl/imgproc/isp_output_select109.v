// Frame-atomic ISP comparison mux. Original is RGB after necessary demosaic,
// before AWB, digital brightness, saturation and gamma. No extra frame buffer.
module isp_output_select109(
 input wire clk,rst_n,request_raw,
 input wire [95:0] raw_rgb,processed_rgb,
 input wire raw_user,raw_valid,raw_last,processed_user,processed_valid,processed_last,
 output wire [95:0] rgb,output wire sof,valid,last
);
 reg raw_active;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)raw_active<=0;
  else if(raw_user)raw_active<=request_raw;
 end

 wire take_raw=raw_user?request_raw:raw_active;
 assign rgb=take_raw?raw_rgb:processed_rgb;
 assign sof=take_raw?raw_user:processed_user;
 assign valid=take_raw?raw_valid:processed_valid;
 assign last=take_raw?raw_last:processed_last;
endmodule

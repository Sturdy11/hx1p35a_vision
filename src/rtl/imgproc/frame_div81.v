module frame_div81(input wire clk,rst_n,start,input wire [31:0] numerator,input wire [23:0] denominator,
 output reg busy,done,output reg [31:0] quotient);
 reg [31:0] q;reg [23:0] rem,den;reg [5:0] bit_count;
 wire [24:0] trial={rem,q[31]};wire [24:0] sub=trial-{1'b0,den};
 wire [31:0] next_q={q[30:0],!sub[24]};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin busy<=0;done<=0;quotient<=0;q<=0;rem<=0;den<=0;bit_count<=0;end
  else begin
   done<=0;
   if(start&&!busy)begin
    if(denominator==0)begin quotient<=32'hffffffff;done<=1;end
    else begin busy<=1;q<=numerator;rem<=0;den<=denominator;bit_count<=0;end
   end else if(busy)begin
    rem<=sub[24]?trial[23:0]:sub[23:0];q<=next_q;
    if(bit_count==31)begin quotient<=next_q;busy<=0;done<=1;end
    else bit_count<=bit_count+1'b1;
   end
  end
 end
endmodule

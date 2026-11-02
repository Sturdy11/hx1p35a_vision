module key_action80 #(parameter DEBOUNCE_CYCLES=1000000, LONG_CYCLES=100000000)(
 input wire clk,rst_n,key_n,output reg short_pulse,long_pulse
);
 localparam DW=$clog2(DEBOUNCE_CYCLES+1),LW=$clog2(LONG_CYCLES+1);
 reg sync1,sync2,pressed,long_sent;
 reg [DW-1:0] debounce;reg [LW-1:0] duration;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin sync1<=1;sync2<=1;pressed<=0;long_sent<=0;debounce<=0;duration<=0;short_pulse<=0;long_pulse<=0;end
  else begin
   sync1<=key_n;sync2<=sync1;short_pulse<=0;long_pulse<=0;
   if((!sync2)==pressed)debounce<=0;
   else if(debounce==DEBOUNCE_CYCLES-1)begin
    debounce<=0;pressed<=!sync2;duration<=0;
    if(!sync2)long_sent<=0;
    else if(!long_sent)short_pulse<=1;
   end else debounce<=debounce+1'b1;
   if(pressed&&!long_sent&&!sync2)begin
    if(duration==LONG_CYCLES-1)begin long_pulse<=1;long_sent<=1;end
    else duration<=duration+1'b1;
   end
  end
 end
endmodule

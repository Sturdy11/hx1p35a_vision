// Serial movement-aware target selection. History and output packets remain atomic.
// AUTO follows confirmed moving tracks; KEY4 short selects MAN; HOLD retains old coordinates.
module focus114 #(parameter N=24)(
 input wire clk,rst_n,enable,start,next_toggle,
 input wire [N-1:0] objects,held,
 input wire [N*9-1:0] x0,x1,input wire [N*8-1:0] y0,y1,
 input wire [N*3-1:0] classes,
 output reg valid,hold_state,output reg [4:0] id,output reg [11:0] cx,cy,
 output wire busy,output reg auto_mode,moving
);
 reg [1:0] phase;reg scanning,seen_toggle,advance,manual_scan;
 reg [4:0] idx,steps;reg [N-1:0] history;
 (* ram_style="block" *) reg [21:0] previous[0:31]; //synthesis ram_style=bram
 reg [21:0] old_q;
 reg [9:0] sx;reg [8:0] sy;reg [2:0] cls;reg live_now,held_now;
 reg first_valid,current_valid,best_valid,current_motion;
 reg [4:0] first_id,best_id;reg first_held;
 reg [9:0] first_x,current_x,best_x;reg [8:0] first_y,current_y,best_y;
 reg [10:0] best_score;reg [2:0] motion_life;
 wire [4:0] following=id==N-1?5'd0:id+1'b1;
 wire [9:0] delta_x=sx>=old_q[18:9]?sx-old_q[18:9]:old_q[18:9]-sx;
 wire [8:0] delta_y=sy>=old_q[8:0]?sy-old_q[8:0]:old_q[8:0]-sy;
 wire [10:0] score={1'b0,delta_x}+{2'b0,delta_y};

 wire observed_motion=history[idx]&&live_now&&!held_now&&cls!=0&&
                      old_q[21:19]==cls&&score>=6;
 assign busy=scanning;
 always @(posedge clk)begin
  old_q<=previous[idx];
  if(rst_n&&enable&&scanning&&phase==2)previous[idx]<={cls,sx,sy};
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   scanning<=0;phase<=0;seen_toggle<=0;advance<=0;manual_scan<=0;idx<=0;steps<=0;history<=0;
   valid<=0;hold_state<=0;id<=0;cx<=0;cy<=0;auto_mode<=1;moving<=0;motion_life<=0;
   sx<=0;sy<=0;cls<=0;live_now<=0;held_now<=0;first_valid<=0;current_valid<=0;best_valid<=0;current_motion<=0;
   first_id<=0;best_id<=0;first_held<=0;first_x<=0;current_x<=0;best_x<=0;first_y<=0;current_y<=0;best_y<=0;best_score<=0;
  end else if(!enable)begin
   scanning<=0;valid<=0;hold_state<=0;history<=0;seen_toggle<=next_toggle;advance<=0;auto_mode<=1;moving<=0;motion_life<=0;
  end else begin
   if(next_toggle!=seen_toggle)begin seen_toggle<=next_toggle;advance<=1;auto_mode<=0;end
   if(start&&!scanning)begin
    scanning<=1;phase<=0;steps<=0;first_valid<=0;current_valid<=0;best_valid<=0;current_motion<=0;best_score<=0;
    manual_scan<=advance||next_toggle!=seen_toggle;
    idx<=(advance||next_toggle!=seen_toggle)?following:id;advance<=0;
   end else if(scanning)begin
    case(phase)
     0:begin
      sx<={1'b0,x0[idx*9+:9]}+{1'b0,x1[idx*9+:9]};
      sy<={1'b0,y0[idx*8+:8]}+{1'b0,y1[idx*8+:8]};
      cls<=classes[idx*3+:3];live_now<=objects[idx];held_now<=held[idx];phase<=1;
     end
     1:phase<=2;
     2:begin
      history[idx]<=live_now&&!held_now;
      if(live_now&&!first_valid)begin first_valid<=1;first_id<=idx;first_x<=sx;first_y<=sy;first_held<=held_now;end
      if(live_now&&idx==id)begin current_valid<=1;current_x<=sx;current_y<=sy;current_motion<=observed_motion;end
      if(observed_motion&&(!best_valid||score>best_score))begin best_valid<=1;best_id<=idx;best_x<=sx;best_y<=sy;best_score<=score;end
      if(steps==N-1)phase<=3;
      else begin idx<=idx==N-1?5'd0:idx+1'b1;steps<=steps+1'b1;phase<=0;end
     end
     default:begin
      scanning<=0;valid<=first_valid;
      if(first_valid)begin
       if(manual_scan||(!auto_mode&&current_valid))begin
        id<=first_id;cx<={first_x,1'b0}+1'b1;cy<={2'd0,first_y,1'b0}+1'b1;hold_state<=first_held;
        moving<=!first_held&&current_motion&&first_id==id;motion_life<=0;
       end else if(current_motion||(auto_mode&&current_valid&&motion_life!=0))begin
        cx<={current_x,1'b0}+1'b1;cy<={2'd0,current_y,1'b0}+1'b1;hold_state<=held[id];
        moving<=!held[id];motion_life<=current_motion?3'd6:motion_life-1'b1;
       end else if(best_valid)begin
        id<=best_id;cx<={best_x,1'b0}+1'b1;cy<={2'd0,best_y,1'b0}+1'b1;hold_state<=0;moving<=1;motion_life<=6;
       end else begin
        id<=first_id;cx<={first_x,1'b0}+1'b1;cy<={2'd0,first_y,1'b0}+1'b1;hold_state<=first_held;moving<=0;motion_life<=0;
        if(!current_valid)auto_mode<=1;
       end
      end else begin hold_state<=0;moving<=0;motion_life<=0;auto_mode<=1;end
     end
    endcase
   end
  end
 end
endmodule

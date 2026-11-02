module scene_stabilize110 #(parameter N=24,KEEP_FRAMES=12,NEEDLE_KEEP_FRAMES=24)(
 input wire clk,rst_n,enable,frame_tick,hold_updates,
 input wire [15:0] sequence_id,input wire [3:0] status,
 input wire [N-1:0] in_objects,
 input wire [N*9-1:0] in_x0,in_x1,input wire [N*8-1:0] in_y0,in_y1,
 input wire [N*3-1:0] in_classes,input wire [N*2-1:0] in_ring_ends,
 output wire [N-1:0] objects,
 output wire [N*9-1:0] box_x0,box_x1,output wire [N*8-1:0] box_y0,box_y1,
 output wire [N*3-1:0] classes,output reg [41:0] counts,
 output reg [15:0] result_sequence,output wire [N-1:0] held,
 output wire busy
);
 localparam IDLE=0,LOAD=1,SEARCH=2,UPDATE=3,NEXT=4,COUNT=5,APPLY=6,COORD=7,FETCH=8,TERMS=9,GEOMETRY=10,FLAGS=11,CLEAN_LOAD=12,CLEAN_SCAN=13,CLEAN_CHECK=14,CLEAN_NEXT=15,PRE_SCAN=16,PRE_CHECK=17;
 reg [4:0] state;reg age_pending;
 reg [N-1:0] live,confirmed,used;
 reg [8:0] tx0[0:N-1],tx1[0:N-1];
 reg [7:0] ty0[0:N-1],ty1[0:N-1];
 reg [1:0] track_rings[0:N-1];reg [1:0] drings,orings;
 reg [2:0] tc[0:N-1],pending_class[0:N-1];
 reg [2:0] votes[0:N-1];reg [2:0] shrink_votes[0:N-1];reg shrink_freeze;reg [4:0] age[0:N-1];
 reg [15:0] accepted_seq,processed_seq;
 reg [4:0] di,ti,ci;
 reg [8:0] dx0,dx1;reg [7:0] dy0,dy1;reg [2:0] dc;
 reg found,free_found,suppress,recount;
 reg [4:0] best,free_slot;
 reg [10:0] best_score;
 reg new_track;reg [1:0] axis;
 assign busy=state!=IDLE;
 assign objects=live&confirmed;
 genvar g;
 generate for(g=0;g<N;g=g+1) begin:pack
  assign box_x0[g*9+:9]=tx0[g];assign box_x1[g*9+:9]=tx1[g];
  assign box_y0[g*8+:8]=ty0[g];assign box_y1[g*8+:8]=ty1[g];
  assign classes[g*3+:3]=tc[g];
  assign held[g]=live[g]&&confirmed[g]&&age[g]>=3;
 end endgenerate
 function [8:0] distance;
  input [8:0] a,b;
  reg [9:0] d;
  begin d={1'b0,a}-{1'b0,b};distance=d[9]?(~d[8:0]+1'b1):d[8:0];end
 endfunction

 reg [8:0] ox0,ox1;reg [7:0] oy0,oy1;reg [2:0] oc;
 reg [3:0] birth_near;reg shape_stable,birth_anchor_reset;
 reg coord_mode,clean_mode,pre_mode;reg qring_contained,qring_band,qowned;
 reg [8:0] qd0,qd1,qd2,qd3,qocx,qncx,qocy,qncy;
 reg [8:0] qow,qnw,qoh,qnh,qold,qnew;
 reg qcontained,qincoming_contains;
 reg [8:0] qscore,qcenter_dx,qcenter_dy,qsmooth;
 reg qsize_ok,qmatch,qfragment,qkeep,qgauze;
 wire [8:0] min_width=qow<qnw?qow:qnw,min_height=qoh<qnh?qoh:qnh;

 wire gauze_geometry=oc==4&&dc==4&&min_width>=18&&min_height>=18&&
   qcenter_dx<=((min_width>>3)+9'd1)&&qcenter_dy<=((min_height>>3)+9'd1)&&
   distance(qow,qnw)<=((min_width>>2)+9'd2)&&distance(qoh,qnh)<=((min_height>>2)+9'd2);
 wire [8:0] score=qscore;
 wire [8:0] d01=qd0>qd1?qd0:qd1,d23=qd2>qd3?qd2:qd3;
 wire tool=oc>=1&&oc<=3;
 wire needle_pair=live[ti]&&confirmed[ti]&&oc==6&&dc==6;
 wire class_ok=(oc!=6&&dc!=6)||oc==dc||oc==0||dc==0;
 wire translated=oc==dc&&dc!=0&&qcenter_dx<=16&&qcenter_dy<=16&&qsize_ok;
 wire match_ok=qmatch;
 wire fragment=qfragment;
 function [8:0] smooth;
  input [8:0] oldv,newv;
  reg [8:0] delta,step;
  begin
   delta=oldv>newv?oldv-newv:newv-oldv;
   step=({1'b0,delta}+10'd3)>>2;
   if(delta<=1) smooth=oldv;

   else if(delta>4)smooth=newv;
   else smooth=newv>oldv?oldv+step:oldv-step;
  end
 endfunction
 wire ring_swap=(tc[ti]==1&&dc==3)||(tc[ti]==3&&dc==1);
 wire class_switch_ready=ring_swap?votes[ti]>=5:votes[ti]>=2;

 wire contract_pair=tc[ti]!=0&&dc==tc[ti];

 wire cotton_motion=live[ti]&&confirmed[ti]&&oc==5&&dc==5&&qsize_ok&&
   qcenter_dx<=24&&qcenter_dy<=24&&
   distance(qow,qnw)<=((qow>>2)+9'd2)&&distance(qoh,qnh)<=((qoh>>2)+9'd2)&&
   ((qcenter_dx>=3&&((dx0>ox0&&dx1>ox1)||(dx0<ox0&&dx1<ox1)))||
    (qcenter_dy>=3&&((dy0>oy0&&dy1>oy1)||(dy0<oy0&&dy1<oy1))));
 reg cotton_update;
 wire cotton_follow=coord_mode&&!new_track&&(axis==0?cotton_motion:cotton_update);
 wire rigid_shift=(shape_stable&&qcenter_dx<=16&&qcenter_dy<=16)||cotton_motion;
 wire material_shrink=coord_mode&&!new_track&&confirmed[ti]&&contract_pair&&
                     qscore>2&&!rigid_shift;

 (* ram_style="block" *) reg [33:0] extent_mem[0:31]; //synthesis ram_style=bram
 reg [33:0] extent_q;

 reg [3:0] extent_near;reg extent_match,quiet_extent;
 wire extent_hold=quiet_extent||(material_shrink&&(!extent_match||shrink_votes[ti]<5));
 wire contract_hold=axis==0?extent_hold:shrink_freeze;
 wire [8:0] smoothed=new_track?qnew:((qkeep||contract_hold)?qold:(cotton_follow?qnew:qsmooth));
 always @(posedge clk)begin
  extent_q<=extent_mem[ti];
  if(rst_n&&enable&&!hold_updates&&state==COORD&&axis==0&&
     (new_track||birth_anchor_reset||(!confirmed[ti]&&(tc[ti]==0||tc[ti]==6))||(material_shrink&&!extent_match)))
   extent_mem[ti]<={dx0,dx1,dy0,dy1};
 end
 integer i;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=IDLE;cotton_update<=0;extent_near<=0;extent_match<=0;quiet_extent<=0;shape_stable<=0;birth_anchor_reset<=0;birth_near<=0;shrink_freeze<=0;age_pending<=0;live<=0;confirmed<=0;used<=0;accepted_seq<=0;processed_seq<=0;result_sequence<=0;counts<=0;
   ox0<=0;ox1<=0;oy0<=0;oy1<=0;oc<=0;coord_mode<=0;clean_mode<=0;pre_mode<=0;drings<=0;orings<=0;qring_contained<=0;qring_band<=0;qowned<=0;
   qd0<=0;qd1<=0;qd2<=0;qd3<=0;qocx<=0;qncx<=0;qocy<=0;qncy<=0;
   qow<=0;qnw<=0;qoh<=0;qnh<=0;qold<=0;qnew<=0;
   qcontained<=0;qincoming_contains<=0;qscore<=0;qcenter_dx<=0;qcenter_dy<=0;qsmooth<=0;
   qsize_ok<=0;qmatch<=0;qfragment<=0;qkeep<=0;qgauze<=0;
   di<=0;ti<=0;ci<=0;dx0<=0;dx1<=0;dy0<=0;dy1<=0;dc<=0;
   found<=0;free_found<=0;suppress<=0;recount<=0;best<=0;free_slot<=0;best_score<=2047;new_track<=0;axis<=0;
   for(i=0;i<N;i=i+1) begin
    track_rings[i]<=0;tx0[i]<=0;tx1[i]<=0;ty0[i]<=0;ty1[i]<=0;tc[i]<=0;
    pending_class[i]<=0;votes[i]<=0;shrink_votes[i]<=0;age[i]<=0;
   end
  end else if(!enable) begin
   state<=IDLE;clean_mode<=0;pre_mode<=0;age_pending<=0;live<=0;confirmed<=0;used<=0;counts<=0;recount<=0;accepted_seq<=sequence_id;processed_seq<=sequence_id;result_sequence<=sequence_id;
  end else if(hold_updates)begin
   if(frame_tick)age_pending<=1;
  end else begin
   if(frame_tick||age_pending) begin
    age_pending<=0;
    recount<=1;
    for(i=0;i<N;i=i+1) if(live[i]) begin
     if(age[i]>=(confirmed[i]?(tc[i]==6?NEEDLE_KEEP_FRAMES-1:KEEP_FRAMES-1):3)) begin live[i]<=0;confirmed[i]<=0;end
     else age[i]<=age[i]+1'b1;
    end
   end
   case(state)
    IDLE:begin
     if(sequence_id!=accepted_seq) begin
      accepted_seq<=sequence_id;
      // Queue overflow/timeout is not evidence that all targets disappeared.
      if(!status[0]&&!status[2]&&!status[3]) begin di<=0;used<=0;clean_mode<=0;pre_mode<=0;processed_seq<=sequence_id;state<=LOAD;end
     end else if(recount) begin ci<=0;counts<=0;recount<=0;state<=COUNT;end
    end
    LOAD:begin
     if(di==N) begin di<=0;clean_mode<=1;state<=CLEAN_LOAD;end
     else if(!in_objects[di]) state<=NEXT;
     else begin
      dx0<=in_x0[di*9+:9];dx1<=in_x1[di*9+:9];dy0<=in_y0[di*8+:8];dy1<=in_y1[di*8+:8];
      drings<=in_ring_ends[di*2+:2];dc<=in_classes[di*3+:3];ti<=0;found<=0;free_found<=0;suppress<=0;best_score<=2047;coord_mode<=0;pre_mode<=in_classes[di*3+:3]==6;state<=in_classes[di*3+:3]==6?PRE_SCAN:FETCH;
     end
    end

    PRE_SCAN:begin
     if(in_objects[ti]&&(in_classes[ti*3+:3]==1||in_classes[ti*3+:3]==3)&&in_ring_ends[ti*2+:2]!=0)state<=FETCH;
     else if(ti==N-1)begin pre_mode<=0;ti<=0;state<=FETCH;end
     else ti<=ti+1'b1;
    end
    PRE_CHECK:begin
     if(qowned)begin pre_mode<=0;state<=NEXT;end
     else if(ti==N-1)begin pre_mode<=0;ti<=0;state<=FETCH;end
     else begin ti<=ti+1'b1;state<=PRE_SCAN;end
    end
    FETCH:begin
     if(pre_mode)begin
      ox0<=in_x0[ti*9+:9];ox1<=in_x1[ti*9+:9];oy0<=in_y0[ti*8+:8];oy1<=in_y1[ti*8+:8];
      orings<=in_ring_ends[ti*2+:2];oc<=in_classes[ti*3+:3];
     end else begin ox0<=tx0[ti];ox1<=tx1[ti];oy0<=ty0[ti];oy1<=ty1[ti];orings<=track_rings[ti];oc<=tc[ti];end
     state<=TERMS;
    end
    TERMS:begin
     birth_near<={distance(extent_q[33:25],dx0)<=2,distance(extent_q[24:16],dx1)<=2,
       distance({1'b0,extent_q[15:8]},{1'b0,dy0})<=2,distance({1'b0,extent_q[7:0]},{1'b0,dy1})<=2};
     extent_near<={distance(extent_q[33:25],dx0)<=1,distance(extent_q[24:16],dx1)<=1,
       distance({1'b0,extent_q[15:8]},{1'b0,dy0})<=1,distance({1'b0,extent_q[7:0]},{1'b0,dy1})<=1};
     qd0<=distance(ox0,dx0);qd1<=distance(ox1,dx1);
     qd2<=distance({1'b0,oy0},{1'b0,dy0});qd3<=distance({1'b0,oy1},{1'b0,dy1});
     qocx<=({1'b0,ox0}+{1'b0,ox1})>>1;qncx<=({1'b0,dx0}+{1'b0,dx1})>>1;
     qocy<=({2'b0,oy0}+{2'b0,oy1})>>1;qncy<=({2'b0,dy0}+{2'b0,dy1})>>1;
     qow<=ox1-ox0+1'b1;qnw<=dx1-dx0+1'b1;
     qoh<={1'b0,oy1}-{1'b0,oy0}+1'b1;qnh<={1'b0,dy1}-{1'b0,dy0}+1'b1;
     qcontained<=({1'b0,dx0}+10'd2)>=ox0&&dx1<=({1'b0,ox1}+10'd2)&&
                  ({1'b0,dy0}+9'd2)>=oy0&&dy1<=({1'b0,oy1}+9'd2);

     qring_contained<=({1'b0,dx0}+10'd1)>=ox0&&dx1<=({1'b0,ox1}+10'd1)&&
                       ({1'b0,dy0}+9'd1)>=oy0&&dy1<=({1'b0,oy1}+9'd1);
     qincoming_contains<=({1'b0,ox0}+10'd2)>=dx0&&ox1<=({1'b0,dx1}+10'd2)&&
                          ({1'b0,oy0}+9'd2)>=dy0&&oy1<=({1'b0,dy1}+9'd2);
     qold<=axis==0?ox0:axis==1?ox1:axis==2?{1'b0,oy0}:{1'b0,oy1};
     qnew<=axis==0?dx0:axis==1?dx1:axis==2?{1'b0,dy0}:{1'b0,dy1};state<=GEOMETRY;
    end
    GEOMETRY:begin
     shape_stable<=oc==dc&&dc!=0&&distance(qow,qnw)<=2&&distance(qoh,qnh)<=2;
     qscore<=d01>d23?d01:d23;
     qcenter_dx<=distance(qocx,qncx);qcenter_dy<=distance(qocy,qncy);
     qsize_ok<=({1'b0,qow}<<1)>=qnw&&({1'b0,qnw}<<1)>=qow&&
               ({1'b0,qoh}<<1)>=qnh&&({1'b0,qnh}<<1)>=qoh;

     if(qoh>=qow)qring_band<=
       (orings[0]&&({1'b0,dy1})<=({1'b0,oy0}+(qoh>>2)+10'd1))||
       (orings[1]&&({1'b0,dy0}+(qoh>>2)+10'd1)>={1'b0,oy1});
     else qring_band<=
       (orings[0]&&({1'b0,dx1})<=({1'b0,ox0}+(qow>>2)+10'd1))||
       (orings[1]&&({1'b0,dx0}+(qow>>2)+10'd1)>={1'b0,ox1});
     qsmooth<=smooth(qold,qnew);state<=FLAGS;
    end
    FLAGS:begin
     extent_match<=(shrink_votes[ti]!=0||(!confirmed[ti]&&votes[ti]!=0))&&(&extent_near);
     quiet_extent<=coord_mode&&!new_track&&confirmed[ti]&&contract_pair&&qcenter_dx<=1&&qcenter_dy<=1&&qscore<=2;
     qgauze<=gauze_geometry;
     qmatch<=live[ti]&&!used[ti]&&class_ok&&(qscore<=8||translated||cotton_motion||gauze_geometry||(needle_pair&&(qcontained||qincoming_contains)));

     qfragment<=live[ti]&&confirmed[ti]&&tool&&dc!=4&&dc!=5&&(dc!=6||oc==2)&&qcontained&&qscore>8;
     qkeep<=(live[ti]&&confirmed[ti]&&oc!=0&&dc!=oc)||live[ti]&&confirmed[ti]&&oc==6&&(dc==0||(dc==6&&qcontained&&qcenter_dx<=2&&qcenter_dy<=2&&qow<=({1'b0,qnw}+10'd2)&&qoh<=({1'b0,qnh}+10'd2)));
     qowned<=qring_contained&&qring_band&&(oc==1||oc==3)&&
             (qow>=36||qoh>=36)&&qnw<=30&&qnh<=30;
     state<=pre_mode?PRE_CHECK:(clean_mode?CLEAN_CHECK:(coord_mode?COORD:SEARCH));
    end
    SEARCH:begin
     if(match_ok&&(!found||score<best_score)) begin found<=1;best<=ti;best_score<=score;end
     if(!live[ti]&&!free_found) begin free_found<=1;free_slot<=ti;end
     if(fragment||(live[ti]&&used[ti]&&qgauze)) suppress<=1;
     if(ti==N-1)state<=UPDATE;else begin ti<=ti+1'b1;state<=FETCH;end
    end
    UPDATE:begin
     if(found||free_found&&!suppress) begin
      ti<=found?best:free_slot;new_track<=!found;state<=APPLY;
     end else state<=NEXT;
    end
    APPLY:begin

     if(!new_track&&tc[ti]==6&&!confirmed[ti]&&dc!=6) begin live[ti]<=0;votes[ti]<=0;state<=NEXT;end
     else if(!new_track&&tc[ti]==6&&dc==0&&(!live[ti]||age[ti]>=NEEDLE_KEEP_FRAMES-1)) state<=NEXT;
     else begin
     birth_anchor_reset<=0;track_rings[ti]<=drings;live[ti]<=1;used[ti]<=1;axis<=0;
     if(new_track||dc!=0) age[ti]<=0;
     if(new_track||dc!=tc[ti])shrink_votes[ti]<=0;
     if(new_track) begin
      confirmed[ti]<=0;tc[ti]<=dc;pending_class[ti]<=0;votes[ti]<=(dc==6||dc==0)?3'd1:3'd0;
     end else if(tc[ti]==0&&dc==6) begin

      confirmed[ti]<=0;tc[ti]<=6;pending_class[ti]<=0;votes[ti]<=1;birth_anchor_reset<=1;
     end else if((tc[ti]==1||tc[ti]==3)&&!confirmed[ti]) begin

      votes[ti]<=0;pending_class[ti]<=0;
      if(dc==tc[ti])confirmed[ti]<=1;
      else begin tc[ti]<=dc;confirmed[ti]<=0;end
     end else if((tc[ti]==6||tc[ti]==0)&&!confirmed[ti]&&dc==tc[ti]) begin

     end else begin
      if(tc[ti]!=6||dc==6) confirmed[ti]<=1;
      if(tc[ti]==0&&dc!=0) begin tc[ti]<=dc;votes[ti]<=0;end
      else if(dc==tc[ti]||dc==0) votes[ti]<=0;
      else if(pending_class[ti]!=dc||votes[ti]==0) begin pending_class[ti]<=dc;votes[ti]<=1;end
      else if(class_switch_ready) begin tc[ti]<=dc;votes[ti]<=0;end
      else votes[ti]<=votes[ti]+1'b1;
     end
     coord_mode<=1;state<=FETCH;
     end
    end
    COORD:begin
     if(axis==0)begin
      cotton_update<=cotton_motion;
      if(!new_track&&!confirmed[ti]&&(tc[ti]==6||tc[ti]==0)&&dc==tc[ti])begin
       if(!extent_match&&!(shape_stable&&(&birth_near)))votes[ti]<=1;
       else if(votes[ti]>=3)begin confirmed[ti]<=1;votes[ti]<=0;end
       else votes[ti]<=votes[ti]+1'b1;
      end
      shrink_freeze<=extent_hold;
      if(!material_shrink)shrink_votes[ti]<=0;
      else if(!extent_match)shrink_votes[ti]<=1;
      else if(shrink_votes[ti]<5)shrink_votes[ti]<=shrink_votes[ti]+1'b1;
     end
     case(axis)
      0:tx0[ti]<=smoothed;1:tx1[ti]<=smoothed;
      2:ty0[ti]<=smoothed[7:0];3:ty1[ti]<=smoothed[7:0];
     endcase
     if(axis==3) state<=NEXT;else begin axis<=axis+1'b1;state<=FETCH;end
    end
    NEXT:begin di<=di+1'b1;state<=LOAD;end

    CLEAN_LOAD:begin
     if(di<N&&!used[di])shrink_votes[di]<=0;
     if(di==N)begin clean_mode<=0;ci<=0;counts<=0;recount<=0;state<=COUNT;end
     else if(live[di]&&!confirmed[di]&&(tc[di]==0||tc[di]==6||tc[di]==1||tc[di]==3)&&!used[di]) begin

      live[di]<=0;votes[di]<=0;state<=CLEAN_NEXT;
     end else if(!live[di]||!confirmed[di]||(tc[di]!=6&&tc[di]!=4))state<=CLEAN_NEXT;
     else begin
      dx0<=tx0[di];dx1<=tx1[di];dy0<=ty0[di];dy1<=ty1[di];dc<=tc[di];ti<=0;state<=CLEAN_SCAN;
     end
    end
    CLEAN_SCAN:begin

     if(ti!=di&&live[ti]&&confirmed[ti]&&used[ti]&&
       ((dc==6&&(tc[ti]==1||tc[ti]==3)&&track_rings[ti]!=0)||
        (dc==4&&tc[ti]==4&&(!used[di]||ti<di))))state<=FETCH;
     else if(ti==N-1)state<=CLEAN_NEXT;
     else ti<=ti+1'b1;
    end
    CLEAN_CHECK:begin
     if(dc==4?qgauze:qowned)begin live[di]<=0;confirmed[di]<=0;votes[di]<=0;state<=CLEAN_NEXT;end
     else if(ti==N-1)state<=CLEAN_NEXT;
     else begin ti<=ti+1'b1;state<=CLEAN_SCAN;end
    end
    CLEAN_NEXT:begin di<=di+1'b1;state<=CLEAN_LOAD;end
    COUNT:begin
     if(ci==N) begin state<=IDLE;result_sequence<=processed_seq;end
     else begin
      if(live[ci]&&confirmed[ci]) begin
       case(tc[ci])
        0:counts[0+:6]<=counts[0+:6]+1'b1;1:counts[6+:6]<=counts[6+:6]+1'b1;
        2:counts[12+:6]<=counts[12+:6]+1'b1;3:counts[18+:6]<=counts[18+:6]+1'b1;
        4:counts[24+:6]<=counts[24+:6]+1'b1;5:counts[30+:6]<=counts[30+:6]+1'b1;
        6:counts[36+:6]<=counts[36+:6]+1'b1;
       endcase
      end
      ci<=ci+1'b1;
     end
    end
   endcase
  end
 end
endmodule

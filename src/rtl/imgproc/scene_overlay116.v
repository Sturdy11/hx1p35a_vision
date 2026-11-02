module scene_overlay116 # (parameter NOBJ=24)(
 input wire clk,rst_n,de,hs,vs,
 input wire overlay_enable,
 input wire [11:0] light_gain_r,light_gain_b,input wire [1:0] light_state,input wire [7:0] light_mean,
 input wire [11:0] x,y,
 input wire [23:0] rgb,
 input wire [47:0] info_digits,input wire [2:0] motion_state,
 input wire [23:0] rates,input wire [127:0] decimal_digits,
 input wire focus_auto,focus_moving,input wire focus_held,input wire [11:0] focus_x,focus_y,
 input wire video_valid,latency_valid,latency_fault,input wire [15:0] video_frame,repeat_frames,skip_frames,
 input wire focus_valid,input wire [4:0] focus_id,input wire [2:0] audit_state,
 input wire learning,preview_ready,input wire [35:0] candidate,
 input wire [35:0] baseline,missing_amount,input wire [5:0] missing,
 input wire motion_box,input wire [11:0] mx0,mx1,my0,my1,input wire [7:0] mean_level,
 input wire [NOBJ-1:0] objects,
 input wire [NOBJ*9-1:0] box_x0,box_x1,
 input wire [NOBJ*8-1:0] box_y0,box_y1,
 input wire [NOBJ*3-1:0] classes,
 input wire [41:0] counts,input wire [2:0] display_mode,
 input wire [3:0] status,
 input wire [15:0] sequence_id,
 input wire [95:0] diagnostics,
 input wire [7:0] video_status,input wire update_safe,packet_commit,
 input wire [7:0] rx_drops,input wire cfg_done,cfg_error,
 output reg out_de,out_hs,out_vs,
 output reg [23:0] out_rgb
);
 reg [11:0] snap_wbr,snap_wbb;reg [1:0] snap_light;reg [7:0] snap_light_mean;
 reg [7:0] snap_rx_drops;reg snap_cfg_done,snap_cfg_error;
 reg snap_auto,snap_moving;reg snap_held,snap_vvalid,snap_lvalid,snap_lfault;reg [11:0] snap_fx,snap_fy;
 reg [15:0] snap_vframe,snap_repeat,snap_skip;
 reg [23:0] snap_rates;reg [127:0] snap_decimal;reg snap_focus,snap_motion;
 reg snap_learning,snap_preview;reg [35:0] snap_candidate;
 reg [4:0] snap_id;reg [2:0] snap_audit;reg [35:0] snap_base,snap_amount;reg [5:0] snap_missing;
 reg [11:0] snap_mx0,snap_mx1,snap_my0,snap_my1;reg [7:0] snap_mean;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin snap_learning<=0;snap_preview<=0;snap_candidate<=0;snap_wbr<=256;snap_wbb<=256;snap_light<=3;snap_light_mean<=0;snap_rx_drops<=0;snap_cfg_done<=0;snap_cfg_error<=0;snap_auto<=1;snap_moving<=0;snap_held<=0;snap_vvalid<=0;snap_lvalid<=0;snap_lfault<=0;snap_fx<=0;snap_fy<=0;snap_vframe<=0;snap_repeat<=0;snap_skip<=0;snap_rates<=0;snap_decimal<=0;snap_focus<=0;snap_id<=0;snap_audit<=0;snap_base<=0;snap_amount<=0;snap_missing<=0;
   snap_motion<=0;snap_mx0<=0;snap_mx1<=0;snap_my0<=0;snap_my1<=0;snap_mean<=0;end
  else if(packet_commit&&update_safe)begin
   snap_wbr<=light_gain_r;snap_wbb<=light_gain_b;snap_light<=light_state;snap_light_mean<=light_mean;snap_rx_drops<=rx_drops;snap_cfg_done<=cfg_done;snap_cfg_error<=cfg_error;
   snap_rates<=rates;snap_decimal<=decimal_digits;
   snap_auto<=focus_auto;snap_moving<=focus_moving;snap_held<=focus_held;snap_fx<=focus_x;snap_fy<=focus_y;snap_vvalid<=video_valid;snap_lvalid<=latency_valid;snap_lfault<=latency_fault;
   snap_vframe<=video_frame;snap_repeat<=repeat_frames;snap_skip<=skip_frames;snap_focus<=focus_valid;snap_id<=focus_id;
   snap_learning<=learning;snap_preview<=preview_ready;snap_candidate<=candidate;snap_audit<=audit_state;snap_base<=baseline;snap_amount<=missing_amount;snap_missing<=missing;snap_mean<=mean_level;
   snap_motion<=motion_box;snap_mx0<=mx0;snap_mx1<=mx1;snap_my0<=my0;snap_my1<=my1;
  end
 end
 function [7:0] light_char;input [1:0] st;input [2:0] pos;reg [63:0] word;
 begin case(st)0:word="ADJUST  ";1:word="STABLE  ";2:word="LOW     ";3:word="WAIT    ";endcase
 light_char=word[63-pos*8-:8];end endfunction
 function [7:0] audit_char;input [2:0] st;input [3:0] pos;reg [63:0] word;
 begin if(snap_learning&&snap_preview&&st==2)word="CHECK   ";else case(st)0:word="OFF     ";1:word="SET BASE";2:word="LEARN   ";3:word="MATCH   ";
  4:word="PENDING ";5:word="MISSING ";6:word="REVIEW  ";default:word="STALE   ";endcase
  audit_char=word[63-pos*8-:8];end endfunction
 reg [47:0] snap_info;reg [2:0] snap_motion_state;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin snap_info<=0;snap_motion_state<=0;end
  else if(packet_commit&&update_safe)begin snap_info<=info_digits;snap_motion_state<=motion_state;end
 end
 function [7:0] motion_char;
  input [2:0] st;input [2:0] pos;reg [63:0] word;
  begin case(st)0:word="OFF     ";1:word="WAIT    ";2:word="STILL   ";3:word="MOVE    ";4:word="LIGHT   ";default:word="STALE   ";endcase
  motion_char=word[63-pos*8-:8];end
 endfunction
 reg [2:0] snap_mode;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) snap_mode<=0;
  else if(packet_commit&&update_safe) snap_mode<=display_mode;
 end
 function [7:0] mode_char;
  input [2:0] m;input [3:0] pos;reg [63:0] word;
  begin
   case(m) 0:word="ENHANCE ";1:word="GRAY    ";2:word="BINARY  ";3:word="SEGMENT ";4:word="EDGE    ";5:word="ORIGINAL";default:word="ENHANCE ";endcase
   mode_char=word[63-pos*8-:8];
  end
 endfunction
 reg [NOBJ-1:0] snap_v;
 reg [NOBJ*9-1:0] snap_x0,snap_x1;
 reg [NOBJ*8-1:0] snap_y0,snap_y1;
 reg [NOBJ*3-1:0] snap_c;
 reg [41:0] snap_counts;
 reg [3:0] snap_status;
 reg [15:0] snap_seq;
 reg [95:0] snap_diag;
 reg [7:0] snap_video_status;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin snap_v<=0;snap_x0<=0;snap_x1<=0;snap_y0<=0;snap_y1<=0;snap_c<=0;snap_counts<=0;snap_status<=0;snap_seq<=0;snap_diag<=0;snap_video_status<=0;end
  else if(packet_commit&&update_safe) begin
   snap_v<=objects;snap_x0<=box_x0;snap_x1<=box_x1;snap_y0<=box_y0;snap_y1<=box_y1;
   snap_c<=classes;snap_counts<=counts;snap_status<=status;snap_seq<=sequence_id;
   snap_diag<=diagnostics;snap_video_status<=video_status;
  end
 end

 function [7:0] level_digit;
  input [7:0] v;input [1:0] pos;reg [7:0] rmd;reg [3:0] tens;
  begin
   rmd=v>=200?v-200:v>=100?v-100:v;
   tens=rmd>=90?9:rmd>=80?8:rmd>=70?7:rmd>=60?6:rmd>=50?5:rmd>=40?4:rmd>=30?3:rmd>=20?2:rmd>=10?1:0;
   case(pos)0:level_digit=v>=200?"2":v>=100?"1":"0";
    1:level_digit=8'd48+tens;default:level_digit=8'd48+(rmd-tens*8'd10);endcase
  end
 endfunction
 function [7:0] name_char;
  input [2:0] cl;input [2:0] pos;
  reg [63:0] word;
  begin
   case(cl)
    1:word="SCISSORS";2:word="TWEEZERS";3:word="HEMOSTAT";
    4:word="GAUZE   ";5:word="COTTON  ";6:word="NEEDLE  ";default:word="UNKNOWN ";
   endcase
   name_char=word[63-pos*8-:8];
  end
 endfunction
 function [23:0] color;
  input [2:0] cl;
  begin
   case(cl)
    1:color=24'hffe040;2:color=24'h40ffff;3:color=24'hff8040;
    4:color=24'h80a0ff;5:color=24'hff80ff;6:color=24'h80ff80;default:color=24'hb0b0b0;
   endcase
  end
 endfunction
 function [7:0] hexchar;
  input [3:0] v;
  begin hexchar=(v<10)?8'd48+v:8'd55+v;end
 endfunction
 integer i;
 reg edge_on,text_on,panel_on;
 reg [23:0] ink;
 reg [7:0] ch;
 reg [3:0] font_row;
 reg [2:0] font_col;
 reg [11:0] ax0,ax1,ay0,ay1,tx,ty,dx,dy;
 reg [8:0] gx0,gx1,gy0,gy1,gtx,gty;reg [11:0] selected_tx,selected_ty;
 reg [2:0] cl,text_class,ink_class;reg [4:0] text_id;reg object_ink;
 reg [5:0] cnt;
 reg [5:0] char_index;
 reg [2:0] group_index;
 reg [3:0] group_pos;
 reg [15:0] diag_word;
 integer ai;
 reg a_edge,a_text,a_motion;

 wire [NOBJ-1:0] label_hit,edge_hit,label_first,edge_last,ink_pick;
 wire [NOBJ*9-1:0] label_x,label_y;
 reg [NOBJ-1:0] p_label_hit,p_edge_hit;
 reg [NOBJ*3-1:0] p_classes;
 reg [NOBJ*5-1:0] p_label_x;
 reg [NOBJ*2-1:0] p_label_y;
 reg [11:0] p_x,p_y;reg [23:0] p_rgb;reg p_de,p_hs,p_vs,p_special;

 wire motion_mark=snap_mode==2'd3&&snap_motion&&
   x>=snap_mx0&&x<=snap_mx1&&y>=snap_my0&&y<=snap_my1&&
   (((x==snap_mx0||x==snap_mx1)&&(y[11:3]==snap_my0[11:3]||y[11:3]==snap_my1[11:3]))||
    ((y==snap_my0||y==snap_my1)&&(x[11:3]==snap_mx0[11:3]||x[11:3]==snap_mx1[11:3])));
 wire special_hit=(snap_focus&&((y==snap_fy&&x+5>=snap_fx&&x<=snap_fx+5)||
   (x==snap_fx&&y+5>=snap_fy&&y<=snap_fy+5)))||motion_mark;
 reg p_motion_mark;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin p_label_hit<=0;p_edge_hit<=0;p_x<=0;p_y<=0;p_rgb<=0;p_de<=0;p_hs<=0;p_vs<=0;p_special<=0;p_motion_mark<=0;end
  else begin
   p_label_hit<=label_hit;p_edge_hit<=edge_hit;p_x<=x;p_y<=y;p_rgb<=rgb;p_de<=de;p_hs<=hs;p_vs<=vs;p_special<=special_hit;p_motion_mark<=motion_mark;
  end
 end

 // snapshot with each pixel, including on an atomic packet commit boundary.
 always @(posedge clk)p_classes<=snap_c;
 genvar z;
 generate for(z=0;z<NOBJ;z=z+1)begin:parallel_select
  wire [8:0] x0=snap_x0[z*9+:9],x1=snap_x1[z*9+:9];
  wire [8:0] y0={1'b0,snap_y0[z*8+:8]},y1={1'b0,snap_y1[z*8+:8]};
  wire [8:0] lx=x0>300?9'd300:x0,ly=y0>=4?y0-9'd4:(y1<=175?y1+9'd1:9'd176);
  wire active=snap_v[z]&&x<1280&&y<720;
  assign label_x[z*9+:9]=lx;assign label_y[z*9+:9]=ly;
  assign edge_hit[z]=active&&x[10:2]>=x0&&x[10:2]<=x1&&{1'b0,y[9:2]}>=y0&&{1'b0,y[9:2]}<=y1&&
    ((x[10:2]==x0&&x[1:0]==0)||(x[10:2]==x1&&x[1:0]==3)||
     ({1'b0,y[9:2]}==y0&&y[1:0]==0)||({1'b0,y[9:2]}==y1&&y[1:0]==3));
  assign label_hit[z]=active&&x[10:2]>=lx&&{1'b0,x[10:2]}<({1'b0,lx}+10'd20)&&
    {1'b0,y[9:2]}>=ly&&{1'b0,y[9:2]}<(ly+9'd4);
  always @(posedge clk)begin p_label_x[z*5+:5]<=lx[4:0];p_label_y[z*2+:2]<=ly[1:0];end
  if(z==0)assign label_first[z]=p_label_hit[z];
  else assign label_first[z]=p_label_hit[z]&&!(|p_label_hit[z-1:0]);
  if(z==NOBJ-1)begin
   assign edge_last[z]=p_edge_hit[z];assign ink_pick[z]=label_first[z]||p_edge_hit[z];
  end else begin
   assign edge_last[z]=p_edge_hit[z]&&!(|p_edge_hit[NOBJ-1:z+1]);
   assign ink_pick[z]=(label_first[z]&&!(|p_edge_hit[NOBJ-1:z+1]))||
                      (edge_last[z]&&!(|label_first[NOBJ-1:z+1]));
  end
 end endgenerate
 always @*begin
  gx0=0;gx1=0;gy0=0;gy1=0;gtx=0;gty=0;selected_tx=0;selected_ty=0;
  text_class=0;ink_class=0;text_id=0;object_ink=|ink_pick;cl=0;
  a_edge=(|p_edge_hit)||p_special;a_text=|p_label_hit;a_motion=p_motion_mark;
  for(ai=0;ai<NOBJ;ai=ai+1)begin
   text_class=text_class|(p_classes[ai*3+:3]&{3{label_first[ai]}});
   text_id=text_id|(ai[4:0]&{5{label_first[ai]}});
   selected_tx=selected_tx|({5'd0,p_label_x[ai*5+:5],2'b00}&{12{label_first[ai]}});
   selected_ty=selected_ty|({8'd0,p_label_y[ai*2+:2],2'b00}&{12{label_first[ai]}});
   ink_class=ink_class|(p_classes[ai*3+:3]&{3{ink_pick[ai]}});
  end
 end
 reg [11:0] s_x,s_y;
 reg [23:0] s_rgb;
 reg s_de,s_hs,s_vs,s_edge,s_text,s_motion,s_object_ink;
 reg [2:0] s_text_class,s_ink_class;
 reg [4:0] s_text_id;
 reg [6:0] s_tx;
 reg [3:0] s_ty;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   s_x<=0;s_y<=0;s_rgb<=0;s_de<=0;s_hs<=0;s_vs<=0;
   s_edge<=0;s_text<=0;s_motion<=0;s_object_ink<=0;
   s_text_class<=0;s_ink_class<=0;s_text_id<=0;s_tx<=0;s_ty<=0;
  end else begin
   s_x<=p_x;s_y<=p_y;s_rgb<=p_rgb;s_de<=p_de;s_hs<=p_hs;s_vs<=p_vs;
   s_edge<=a_edge;s_text<=a_text;s_motion<=a_motion;s_object_ink<=object_ink;
   s_text_class<=text_class;s_ink_class<=ink_class;s_text_id<=text_id;
   s_tx<=selected_tx[6:0];s_ty<=selected_ty[3:0];
  end
 end

 always @* begin
  edge_on=s_edge;text_on=s_text;panel_on=0;
  ink=s_object_ink?color(s_ink_class):(s_motion?24'h40a0ff:24'hff8000);
  ch=32;font_row=0;font_col=0;
  ax0=0;ax1=0;ay0=0;ay1=0;tx=0;ty=0;dx=0;dy=0;
  cnt=0;char_index=0;group_index=0;group_pos=0;diag_word=0;
  if(text_on)begin

   dx[6:0]=s_x[6:0]-s_tx;dy[3:0]=s_y[3:0]-s_ty;
   font_row=dy[3:0];font_col=dx[2:0];
   ch=dx[6:3]==0?(s_text_id<10?8'd48+s_text_id:8'd55+s_text_id):(dx[6:3]==1?8'd32:name_char(s_text_class,dx[6:3]-2));
  end

  if(s_x>=8&&s_x<400&&s_y>=8&&s_y<136)begin
   panel_on=1;text_on=1;edge_on=0;ink=24'hffffff;dx=s_x-8;dy=s_y-8;
   char_index=dx[8:3];font_row=dy[3:0];font_col=dx[2:0];ch=32;
   case(dy[6:4])
    0:begin
     case(char_index)0:ch="V";1:ch="1";2:ch="1";3:ch="6";endcase
     for(i=0;i<7;i=i+1)if(char_index>=5+i*6&&char_index<11+i*6)begin
      group_pos=char_index-(5+i*6);cnt=snap_counts[i*6+:6];
      case(group_pos)
       0:case(i)0:ch="U";1:ch="S";2:ch="T";3:ch="H";4:ch="G";5:ch="C";6:ch="N";endcase
       1:ch=":";2:ch=cnt>=20?"2":cnt>=10?"1":"0";
       3:ch=8'd48+(cnt>=20?cnt-6'd20:cnt>=10?cnt-6'd10:cnt);default:ch=32;
      endcase
     end
    end
    1:begin
     case(char_index)0:ch="M";1:ch="O";2:ch="D";3:ch="E";4:ch=":";
      16:ch="L";17:ch="I";18:ch="G";19:ch="H";20:ch="T";21:ch=":";endcase
     if(char_index>=5&&char_index<13)ch=mode_char(snap_mode,char_index-5);
     if(char_index>=22&&char_index<30)ch=light_char(snap_light,char_index-22);
     if(char_index==32)ch="Y";if(char_index==33)ch=":";
     if(char_index>=34&&char_index<=36)ch=level_digit(snap_light_mean,char_index-34);
    end
    2:begin
     ink=24'h80ffff;
     case(char_index)0:ch="V";1:ch="I";2:ch="D";3:ch="E";4:ch="O";5:ch=":";
      10,27:ch="M";11,28:ch="S";
      16:ch="R";17:ch="E";18:ch="S";19:ch="U";20:ch="L";21:ch="T";22:ch=":";
      32:ch="E";33:ch=":";34:ch=hexchar(snap_status);36:ch="Q";37:ch=":";
     endcase
     if(char_index>=6&&char_index<=9)ch=snap_vvalid?8'd48+snap_decimal[64+(9-char_index)*4+:4]:"X";
     if(char_index>=23&&char_index<=26)ch=snap_lvalid?8'd48+snap_decimal[80+(26-char_index)*4+:4]:"X";
     if(char_index>=38&&char_index<=41)ch=hexchar(snap_seq[(41-char_index)*4+:4]);
    end
    3:begin
     ink=snap_audit==5?24'hff8040:(snap_audit==6||snap_audit==7)?24'hffff80:24'h80ff80;
     case(char_index)0:ch="A";1:ch="U";2:ch="D";3:ch="I";4:ch="T";5:ch=":";endcase
     if(char_index>=6&&char_index<14)ch=audit_char(snap_audit,char_index-6);

     if(char_index>=16)begin
      ink=24'h80ffff;
      case(char_index)
       16:ch="C";17:ch="A";18:ch="M";19:ch=":";
       20:ch=8'd48+snap_rates[23:20];21:ch=8'd48+snap_rates[19:16];
       23:ch="H";24:ch="D";25:ch="M";26:ch="I";27:ch=":";
       28:ch=8'd48+snap_rates[15:12];29:ch=8'd48+snap_rates[11:8];
       31:ch="D";32:ch="E";33:ch="T";34:ch=":";
       35:ch=8'd48+snap_rates[7:4];36:ch=8'd48+snap_rates[3:0];
       38:ch="F";39:ch="P";40:ch="S";
      endcase
     end
    end
    4,5:begin
     ink=dy[6:4]==4?24'h80a0ff:((|snap_missing)?24'hff8040:24'h80ff80);
     if(dy[6:4]==5&&snap_learning)begin
      case(char_index)0:ch="C";1:ch="A";2:ch="N";3:ch="D";4:ch=":";endcase
      ink=snap_preview?24'hffff80:24'h80ffff;
     end else case(char_index)0:ch=dy[6:4]==4?"B":"M";1:ch=dy[6:4]==4?"A":"I";2:ch="S";3:ch=dy[6:4]==4?"E":"S";4:ch=":";endcase
     for(i=0;i<6;i=i+1)if(char_index>=6+i*6&&char_index<12+i*6)begin
      group_pos=char_index-(6+i*6);cnt=dy[6:4]==4?snap_base[i*6+:6]:(snap_learning?snap_candidate[i*6+:6]:snap_amount[i*6+:6]);
      case(group_pos)
       0:case(i)0:ch="S";1:ch="T";2:ch="H";3:ch="G";4:ch="C";5:ch="N";endcase
       1:ch=":";2:ch=cnt>=20?"2":cnt>=10?"1":"0";
       3:ch=8'd48+(cnt>=20?cnt-6'd20:cnt>=10?cnt-6'd10:cnt);default:ch=32;
      endcase
     end
    end
    6:begin
     ink=snap_held?24'hffff80:24'h80ffff;
     case(char_index)0:ch="I";1:ch="D";2:ch=":";3:ch=snap_focus?hexchar(snap_id[3:0]):"X";
      7:ch="X";8:ch=":";15:ch="Y";16:ch=":";endcase
     if(char_index==3&&snap_focus&&snap_id>=16)ch=8'd71+snap_id-16;
     if(char_index>=30&&char_index<34)begin
      if(snap_auto)case(char_index)30:ch="A";31:ch="U";32:ch="T";33:ch="O";endcase
      else case(char_index)30:ch="M";31:ch="A";32:ch="N";endcase
     end
     if(char_index>=9&&char_index<=12)ch=snap_focus?8'd48+snap_info[(12-char_index)*4+:4]:"X";
     if(char_index>=17&&char_index<=20)ch=snap_focus?8'd48+snap_info[16+(20-char_index)*4+:4]:"X";
     if(char_index>=24&&char_index<28)begin
      if(!snap_focus)case(char_index)24:ch="N";25:ch="O";26:ch="N";27:ch="E";endcase
      else if(snap_held)case(char_index)24:ch="H";25:ch="O";26:ch="L";27:ch="D";endcase
      else if(snap_moving)case(char_index)24:ch="M";25:ch="O";26:ch="V";27:ch="E";endcase
      else case(char_index)24:ch="L";25:ch="I";26:ch="V";27:ch="E";endcase
     end
    end
    7:begin
     ink=snap_motion_state==3?24'h40a0ff:24'h80ffff;
     case(char_index)0:ch="M";1:ch="O";2:ch="T";3:ch="I";4:ch="O";5:ch="N";6:ch=":";
      18:ch="C";19:ch="E";20:ch="L";21:ch="L";22:ch="S";23:ch=":";endcase
     if(char_index>=7&&char_index<15)ch=motion_char(snap_motion_state,char_index-7);
     if(char_index>=24&&char_index<28)ch=8'd48+snap_info[32+(27-char_index)*4+:4];
    end
    default:begin text_on=0;end
   endcase
  end

 end
 wire [5:0] font_index=(ch>=65&&ch<=90)?ch-8'd54:((ch>=48&&ch<=57)?ch-8'd47:(ch==58?6'd37:6'd0));
 wire [15:0] font_bits;
 osd_font_rom font(.I_clk(clk),.I_idx(font_index),.I_row(font_row),.I_cjk(1'b0),.O_bits(font_bits));
 wire [11:0] ldx=s_x-1120,ldy=s_y-560;

 wire logo_on=s_x>=1120&&s_x<1280&&s_y>=560&&s_y<720;
 wire [14:0] lpos=(ldy[7:0]*15'd160)+ldx;
 wire [7:0] logo_byte;
 logo_rom logo(.I_clk(clk),.I_addr(lpos[14:2]),.O_data(logo_byte));
 reg [1:0] logo_sel_d;
 reg logo_d,edge_d,text_d,panel_d,de_d,hs_d,vs_d;
 reg [2:0] col_d;
 reg [23:0] rgb_d,ink_d;
 wire [1:0] pal=(logo_byte>>(logo_sel_d*2))&2'b11;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   logo_sel_d<=0;logo_d<=0;edge_d<=0;text_d<=0;panel_d<=0;de_d<=0;hs_d<=0;vs_d<=0;col_d<=0;rgb_d<=0;ink_d<=0;
   out_de<=0;out_hs<=0;out_vs<=0;out_rgb<=0;
  end else begin
   logo_sel_d<=lpos[1:0];logo_d<=logo_on&&overlay_enable;edge_d<=edge_on&&overlay_enable;text_d<=text_on&&overlay_enable;panel_d<=panel_on&&overlay_enable;
   de_d<=s_de;hs_d<=s_hs;vs_d<=s_vs;col_d<=font_col;rgb_d<=s_rgb;ink_d<=ink;
   out_de<=de_d;out_hs<=hs_d;out_vs<=vs_d;
   if(!de_d) out_rgb<=0;
   else if(text_d&&font_bits[7-col_d]) out_rgb<=ink_d;
   else if(edge_d) out_rgb<=ink_d;
   else if(panel_d) out_rgb<=24'h101b28;
   else if(logo_d&&pal!=0) out_rgb<=pal==1?24'h1f315c:(pal==2?24'hec1c2d:24'hffffff);
   else out_rgb<=rgb_d;
  end
 end
endmodule

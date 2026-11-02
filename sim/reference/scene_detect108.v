// V108: bright near-neutral white branch tolerates a bounded reflected-green tint.
// V102: sequential direction min/max memory, exact V101 class geometry.
// V101: retain subthreshold bright bridges; measured linear glints release a second bounded tool merge; inclined rail profile.
// V97: same V95 arc policy with synchronous metadata RAM and serial bounded shift/add.
// V95: bounded centroid bend evidence distinguishes close same-turn arcs from complementary fragments.
// V94: bright axial coverage, seed-ring profiles and independent dim blade evidence.
// V89: count bright solid blade sections opposite measured finger rings.
// V88: weak needle contours need nonlinear center or width profile support.
// V87: serial spatially distributed bright support for small needle ROIs.
// V85: green-only regional threshold ratios; V83 CCL/classifier/ring logic retained.
// V83: ring-end evidence accompanies the unchanged V79 classes.
// V79: white-first two-pass CCL, 24 outputs and 24 candidates.
// Compact white targets survive a weak background flood; V74 metal merging retained.
// Inside-box ring fragments and elongated shaft fragments retain V72 stitching.
// No image-position rule, extra pixel RAM, floating point, or neural accelerator.
// merge, seven rule labels. Every large RAM has one reset-free write port.
// Outputs are frame-atomic GRID coordinates; renderer expands by four.
module scene_detect108 #(
 parameter W=1280,H=720,GW=W/4,GH=H/4,NOBJ=24,NCAND=24,
 parameter LOCAL_ADAPT=1,MIN_LEVEL=20,WHITE_LEVEL=100,MIN_COMPONENT=12,QUEUE_DEPTH=4096,
 parameter NEEDLE_SEED_LEVEL=48,NEEDLE_MIN_SEEDS=3,MAX_TOOL_WIDTH=80,
 parameter RIGHT_INVALID_PIXELS=0,GUARD_PIXELS=16,MAX_LEVEL=36,EXCESS_POOL=GW*GH/24,GREEN_RECOVER=16384,TOOL_CORE_LEVEL=64,CLUTTER_POOL=GW*GH/18
)(
 input wire clk,rst_n,valid,enable,input wire [11:0] x,y,input wire [23:0] rgb,
 output reg [NOBJ-1:0] objects,output reg [NOBJ*9-1:0] box_x0,box_x1,
 output reg [NOBJ*8-1:0] box_y0,box_y1,output reg [NOBJ*3-1:0] classes,
 output reg [NOBJ*2-1:0] ring_ends,output reg [41:0] counts,output reg [3:0] status,
 output reg [15:0] sequence_id,output wire busy,
 output reg [95:0] diagnostics,output wire pixel_mask
);
 localparam IDLE=0,CAP=1,SCAN=2,SWAIT=3,SCHECK=4,NADDR=5,NWAIT=6,NCHECK=7,
 POP=8,PWAIT=9,PUSE=10,SAVE=11,MERGE=12,LOAD=13,CLASSIFY=14,EMIT=15,DONE=16,
 FADDR=17,FWAIT=18,FCHECK=19,FSPLIT=20,MDECIDE=21,MCOMMIT=22,
 INIT=23,IWAIT=24,ICHECK=25,IWAIT2=26,SWAIT2=27,NWAIT2=28,PWAIT2=29,FWAIT2=30,
 SLOT=31,INSERT=32,ADVANCE=33,SECOND=34,WHITE_CHECK=35,RTEST=36,RSCAN=37,RRETURN=38,RPAIR=39,NDECIDE=40,MOMENT=41,MOMENT_BIAS=42,BEND_FETCH=43,BEND_WAIT=44,MOMENT_PRODUCT=45,LINE_GEOM=46,LINE_DECIDE=47,GINIT=48,GREAD=49,GWRITE=50,GSCORE_READ=51;
 reg [5:0] state;
 assign busy=state!=IDLE;
 localparam RECOVER_LEVEL=MIN_LEVEL<=MAX_LEVEL?MIN_LEVEL:MAX_LEVEL;
 wire [7:0] local_level,local_white,local_seed,local_core;
 wire local_ready,local_busy;wire [15:0] light_map_sequence;
 reg [7:0] level;reg [15:0] weak_count;
 reg [15:0] pool_count,white_count,read_count,max_area,green_samples;
 // White-only CCL candidates are the only deduplication references.
 reg white_mode;reg frame_contamination;reg metal_phase;reg [5:0] white_slot,white_nc;
 wire [15:0] nonwhite_count=pool_count>=white_count?pool_count-white_count:16'd0;
 wire clutter_frame=nonwhite_count>CLUTTER_POOL;
 reg [3:0] sparse_frames;
 function [15:0] addr;input [8:0] ax;input [7:0] ay;begin addr=ay*GW+ax;end endfunction
 wire [7:0] r=rgb[23:16],g=rgb[15:8],b=rgb[7:0];
 wire [7:0] mx0=r>g?r:g,mn0=r<g?r:g;
 wire [7:0] mx=mx0>b?mx0:b,mn=mn0<b?mn0:b;
 wire [8:0] chroma={1'b0,mx}-{1'b0,mn};
 wire signed [10:0] ex=$signed({2'b0,g,1'b0})-$signed({3'b0,r})-$signed({3'b0,b});
 wire signed [15:0] ex16=$signed({{5{ex[10]}},ex})<<<4;
 wire [9:0] sum={2'b0,r}+{2'b0,g}+{2'b0,b};
 wire green=({1'b0,g}>{1'b0,r}+9'd4)&&({1'b0,g}>{1'b0,b}+9'd2)&&(ex16>$signed({6'b0,sum}));
 // General frame-edge guard. Full 1280-column stream is enabled in V70.
 wire active_region=x>=GUARD_PIXELS&&x<W-RIGHT_INVALID_PIXELS-GUARD_PIXELS&&
                    y>=GUARD_PIXELS&&y<H-GUARD_PIXELS;
 wire fg=active_region&&mx>=local_level&&!green&&({1'b0,chroma,1'b0}<={2'b0,mx}+10'd20);
 // Mask preview includes the independent white branch.
 wire [8:0] gx=x[10:2];wire [7:0] gy=y[9:2];
 // White support is independent of the adaptive low-light metal threshold.
 // A bright textile can have modest green excess from the drape. Require
 // both the existing minimum-channel threshold and a tighter relative chroma
 // bound to bypass the green veto. Saturated/dark green keeps its old mask.
 wire reflected_white=({1'b0,chroma,2'b0}<=({3'b0,mx}+11'd32));
 wire wh=active_region&&mn>=local_white&&chroma<=80&&(!green||reflected_white);
 assign pixel_mask=fg||wh;
 // A weak contour alone is not a needle: require bright foreground in >=3 distinct 4x4 cells.
 wire seed=fg&&mx>=local_seed;
 reg row_seed;reg col_seed[0:GW-1];
 wire core=fg&&mx>=local_core;
 reg row_core;reg col_core[0:GW-1];
 wire rc=(x[1:0]==0)?core:(row_core|core);
 wire cc=(y[1:0]==0)?rc:(col_core[gx]|rc);
 wire rs=(x[1:0]==0)?seed:(row_seed|seed);
 wire cs=(y[1:0]==0)?rs:(col_seed[gx]|rs);

 reg [2:0] row_fg,row_wh;
 reg [4:0] col_fg[0:GW-1],col_wh[0:GW-1];
 wire [2:0] rf=(x[1:0]==0)?{2'b0,fg}:row_fg+fg;
 wire [2:0] rw=(x[1:0]==0)?{2'b0,wh}:row_wh+wh;
 wire [4:0] cf=(y[1:0]==0)?{2'b0,rf}:col_fg[gx]+rf;
 wire [4:0] cw=(y[1:0]==0)?{2'b0,rw}:col_wh[gx]+rw;
 wire capture=(state==CAP)||(state==IDLE&&enable&&valid&&x==0&&y==0);
 local_light85 #(.WHITE_LEVEL(WHITE_LEVEL),.SEED_LEVEL(NEEDLE_SEED_LEVEL),.CORE_LEVEL(TOOL_CORE_LEVEL)) illumination(
  .clk(clk),.rst_n(rst_n),.enable(enable&&LOCAL_ADAPT&&(W==1280)&&(H==720)),.valid(valid),.x(x),.y(y),.base_level(level),
  .capture_start(state==IDLE&&enable&&valid&&x==0&&y==0),
  .capture_end(state==CAP&&valid&&x==W-1&&y==H-1),
  .sample_valid(capture&&valid&&active_region&&green&&x[2:0]==4&&y[2:0]==4),.sample_green(g),
  .fg_level(local_level),.white_level(local_white),.seed_level(local_seed),.core_level(local_core),
  .ready(local_ready),.meter_busy(local_busy),.map_sequence(light_map_sequence));
 wire cap_we=rst_n&&enable&&capture&&valid&&x[1:0]==3&&y[1:0]==3;
 wire [3:0] cap_data={cc&&(cf>=2),cs&&(cf>=2),cw>=2,cf>=2};
 wire [15:0] cap_addr=addr(gx,gy);
 // No asynchronous reset and one write address/data mux per memory: ERAM inference.
 reg [3:0] raw_mem[0:GW*GH-1];reg seen_mem[0:GW*GH-1];
 reg [16:0] queue_mem[0:QUEUE_DEPTH-1];
 reg [15:0] rd_addr;reg [11:0] queue_addr,read_ptr,write_ptr;
 reg [3:0] raw_q;reg seen_q;reg [16:0] queue_q;
 reg [12:0] queued,queue_peak;
 wire visit_we=rst_n&&enable&&((state==SCHECK&&seen_q)||(state==NCHECK&&seen_q&&queued<QUEUE_DEPTH));
 wire push_we=rst_n&&enable&&state==NCHECK&&seen_q&&queued<QUEUE_DEPTH;
 wire init_we=rst_n&&enable&&state==ICHECK;
 reg [8:0] sx,cx,xmin,xmax;reg [7:0] sy,cy,ymin,ymax;
 reg [3:0] neighbor;
 reg signed [10:0] nx;reg signed [9:0] ny;
 wire nok=nx>=0&&nx<GW&&ny>=0&&ny<GH;
 always @* begin
  nx=$signed({2'b0,cx});ny=$signed({2'b0,cy});
  case(neighbor)
   0:begin nx=nx-1;ny=ny-1;end 1:ny=ny-1;2:begin nx=nx+1;ny=ny-1;end
   3:nx=nx-1;5:nx=nx+1;6:begin nx=nx-1;ny=ny+1;end 7:ny=ny+1;8:begin nx=nx+1;ny=ny+1;end
  endcase
 end
`ifdef SCENE_RAM_LATENCY2
 reg [3:0] raw_delay;reg seen_delay;reg [16:0] queue_delay;
`endif
 always @(posedge clk) begin
`ifdef SCENE_RAM_LATENCY2
  raw_delay<=raw_mem[rd_addr];seen_delay<=seen_mem[rd_addr];queue_delay<=queue_mem[queue_addr];
  raw_q<=raw_delay;seen_q<=seen_delay;queue_q<=queue_delay;
`else
  raw_q<=raw_mem[rd_addr];seen_q<=seen_mem[rd_addr];queue_q<=queue_mem[queue_addr];
`endif
  if(cap_we) raw_mem[cap_addr]<=cap_data;
  // Fill visit RAM from a readback of the completed frame, then clear on visit.
  if(init_we||visit_we) seen_mem[rd_addr]<=init_we?(white_mode?raw_q[1]:raw_q[0]):1'b0;
  if(push_we) queue_mem[write_ptr]<={ny[7:0],nx[8:0]};
  if(rst_n&&enable&&capture&&valid) begin
   row_fg<=rf;row_wh<=rw;row_seed<=rs;row_core<=rc;
   if(x[1:0]==3) begin col_fg[gx]<=cf;col_wh[gx]<=cw;col_seed[gx]<=cs;col_core[gx]<=cc;end
  end
 end
 reg [5:0] nc,mi,mj,ci;
 reg [15:0] area,white_area;
 reg [2:0] seeds;
 reg [2:0] c_seeds[0:NCAND-1];
 reg [2:0] p_seeds;
 wire [3:0] pair_seeds={1'b0,c_seeds[mi]}+{1'b0,c_seeds[mj]};
 reg [NCAND-1:0] cand_valid;
 reg [8:0] c_x0[0:NCAND-1],c_x1[0:NCAND-1];
 reg [7:0] c_y0[0:NCAND-1],c_y1[0:NCAND-1];
 reg [15:0] c_area[0:NCAND-1],c_white[0:NCAND-1];
 reg [NCAND-1:0] c_blob,c_arc,c_line,c_ring_tool;reg linear_retry,linear_found;
 // For <=150-cell arcs, 16-bit absolute-coordinate sums are exact even
 // at the right/bottom image edge. Larger components may wrap, but never
 // use this bend evidence. Two pipelined products precede descriptor save.
 // Actual component samples, before any arc repair, define its straightness.
 function signed [10:0] projection;
  input signed [10:0] px,py;input [2:0] mode;
  begin case(mode)0:projection=px;1:projection=py;2:projection=px-py;3:projection=px+py;
   4:projection=(px<<<1)-py;5:projection=(px<<<1)+py;
   6:projection=px-(py<<<1);default:projection=px+(py<<<1);endcase end
 endfunction
 reg [2:0] product_bit;
 // Reset-free memory; all eight bins initialize for every metal component.
 (* ram_style="block" *) reg [21:0] geom_mem[0:7]; //synthesis ram_style=bram
 reg [21:0] geom_q;reg [2:0] geom_index;reg [10:0] geom_x,geom_y;reg [5:0] geom_return;
 wire [2:0] geom_address=(state==GSCORE_READ||state==MOMENT_PRODUCT)?product_bit:geom_index;
 wire signed [10:0] geom_value=projection($signed(geom_x),$signed(geom_y),geom_index);
 wire signed [10:0] geom_min=geom_q[10:0],geom_max=geom_q[21:11];
 wire [21:0] geom_data=state==GINIT?{geom_value,geom_value}:
            {($signed(geom_value)>$signed(geom_max)?geom_value:geom_max),
             ($signed(geom_value)<$signed(geom_min)?geom_value:geom_min)};
 always @(posedge clk)begin
  geom_q<=geom_mem[geom_address];
  if(state==GINIT||state==GWRITE)geom_mem[geom_index]<=geom_data;
 end
 reg [13:0] best_line_score;reg [2:0] best_direction,component_direction;
 reg component_line;
 wire [11:0] projection_span=$signed({geom_q[21],geom_q[21:11]})-$signed({geom_q[10],geom_q[10:0]});
 reg [13:0] projection_score;
 always @*begin
  case(product_bit)0,1:projection_score={2'b0,projection_span}<<3;
   2,3:projection_score=({2'b0,projection_span}<<2)+({2'b0,projection_span}<<1);
   default:projection_score={2'b0,projection_span}<<2;endcase
 end
 reg p_line_i,p_line_j,p_ring_i,p_ring_j,p_collinear;reg [2:0] p_direction;
 reg signed [10:0] p_cdx,p_cdy;
 wire signed [11:0] wide_dx={p_cdx[10],p_cdx},wide_dy={p_cdy[10],p_cdy};
 wire [10:0] abs_cdx=p_cdx[10]?-p_cdx:p_cdx,abs_cdy=p_cdy[10]?-p_cdy:p_cdy;
 wire [11:0] corridor_base=(({1'b0,abs_cdx}+{1'b0,abs_cdy})>>2)+12'd4;
 reg signed [11:0] cross_value;reg [11:0] corridor_value;
 reg [11:0] saved_cross,saved_corridor;
 always @*begin
  case(p_direction)
   0:cross_value=wide_dx;1:cross_value=-wide_dy;2:cross_value=wide_dx-wide_dy;
   3:cross_value=-wide_dx-wide_dy;4:cross_value=(wide_dx<<<1)-wide_dy;
   5:cross_value=-(wide_dx<<<1)-wide_dy;6:cross_value=wide_dx-(wide_dy<<<1);
   default:cross_value=-wide_dx-(wide_dy<<<1);endcase
  corridor_value=p_direction<=1?corridor_base:p_direction<=3?(corridor_base<<1):((corridor_base<<1)+corridor_base);
 end
 reg [15:0] moment_x,moment_y;
 reg [16:0] center_mass_x,center_mass_y;
 reg [3:0] component_bend;
 reg [3:0] p_bend;
 // Two reset-free copies give independent synchronous reads with one write.
 (* ram_style="block" *) reg [6:0] bend_mem_i[0:63]; //synthesis ram_style=bram
 (* ram_style="block" *) reg [6:0] bend_mem_j[0:63]; //synthesis ram_style=bram
 reg [6:0] bend_i,bend_j;
 reg [16:0] shift_x,shift_y;reg [7:0] area_shift;

 reg [NCAND-1:0] c_curve;
 reg curve_eval;

 reg p_independent_arcs;
 wire [16:0] twice_moment_x={moment_x,1'b0},twice_moment_y={moment_y,1'b0};
 wire [17:0] moment_margin={2'b0,area}>>2;
 function [3:0] combine_bend;
  input [3:0] a,b;
  begin
   combine_bend={(a[3]|b[3])&&!(a[2]|b[2]),(a[2]|b[2])&&!(a[3]|b[3]),
                 (a[1]|b[1])&&!(a[0]|b[0]),(a[0]|b[0])&&!(a[1]|b[1])};
  end
 endfunction
 wire bend_shared=|(bend_i[3:0]&bend_j[3:0]);
 wire bend_opposed=(bend_i[3]&&bend_j[2])||(bend_i[2]&&bend_j[3])||
                   (bend_i[1]&&bend_j[0])||(bend_i[0]&&bend_j[1]);


 reg [5:0] slot;
 reg resume_save,merge_tried;
 reg [2:0] pass;reg merged;
 wire [8:0] ux0=c_x0[mi]<c_x0[mj]?c_x0[mi]:c_x0[mj];
 wire [8:0] ux1=c_x1[mi]>c_x1[mj]?c_x1[mi]:c_x1[mj];
 wire [7:0] uy0=c_y0[mi]<c_y0[mj]?c_y0[mi]:c_y0[mj];
 wire [7:0] uy1=c_y1[mi]>c_y1[mj]?c_y1[mi]:c_y1[mj];
 wire [8:0] uw=ux1-ux0+1'b1,uh={1'b0,uy1}-{1'b0,uy0}+1'b1;
 wire [8:0] gapx=(c_x1[mi]<c_x0[mj])?c_x0[mj]-c_x1[mi]-1'b1:
                       (c_x1[mj]<c_x0[mi])?c_x0[mi]-c_x1[mj]-1'b1:9'd0;
 wire [8:0] gapy=(c_y1[mi]<c_y0[mj])?c_y0[mj]-c_y1[mi]-1'b1:
                       (c_y1[mj]<c_y0[mi])?c_y0[mi]-c_y1[mj]-1'b1:9'd0;
 wire separate_pair=c_x1[mi]<c_x0[mj]||c_x1[mj]<c_x0[mi]||
                    c_y1[mi]<c_y0[mj]||c_y1[mj]<c_y0[mi];
 wire metal_pair=!c_blob[mi]&&!c_blob[mj];
 wire [8:0] iw=c_x1[mi]-c_x0[mi]+1'b1,ih={1'b0,c_y1[mi]}-c_y0[mi]+1'b1;
 wire [8:0] jw=c_x1[mj]-c_x0[mj]+1'b1,jh={1'b0,c_y1[mj]}-c_y0[mj]+1'b1;
 wire long_seed=iw>=32||ih>=32||jw>=32||jh>=32;
 wire [16:0] pair_area={1'b0,c_area[mi]}+{1'b0,c_area[mj]};
 reg [8:0] p_x0,p_x1,p_w,p_h,p_gapx,p_gapy,p_iw,p_ih,p_jw,p_jh;
 reg [7:0] p_y0,p_y1;
 reg [15:0] p_area,p_white;
 reg p_metal,p_long,p_arc,p_separate,join_eval,arc_eval;
 wire bend_write=(state==INSERT)||(state==MCOMMIT&&cand_valid[mi]&&cand_valid[mj]&&join_eval);
 wire [5:0] bend_address=state==INSERT?slot:mi;
 wire [6:0] bend_data=state==INSERT?{component_direction,component_bend}:{p_direction,p_bend};
 always @(posedge clk)begin
  bend_i<=bend_mem_i[mi];bend_j<=bend_mem_j[mj];
  if(rst_n&&enable&&bend_write)begin bend_mem_i[bend_address]<=bend_data;bend_mem_j[bend_address]<=bend_data;end
 end
 wire [17:0] union_area=p_w*p_h;
 wire close_fragment=(p_gapx<=3&&p_gapy<=6)||(p_gapx<=6&&p_gapy<=3);
 // Preserve compact arcs outside the long component's box. A ring fragment
 // already inside that box may still reconnect; a thin straight shaft does not
 // satisfy the compact-arc aspect test. Local needle-to-needle repair is retained.
 wire join_arc=!(p_line_i&&p_line_j&&!p_collinear)&&!p_independent_arcs&&p_w<=30&&p_h<=30&&p_gapx<=3&&p_gapy<=3&&p_area<=150&&
               ({2'b0,p_area}<<1)<=union_area;
 wire union_compact_white=({1'b0,p_white}<<1)>=p_area&&({2'b0,p_area}<<1)>=union_area&&
                           {1'b0,p_w}<=({1'b0,p_h}<<1)&&{1'b0,p_h}<=({1'b0,p_w}<<1);
 wire union_curve=join_arc&&p_area>=MIN_COMPONENT&&p_seeds>=NEEDLE_MIN_SEEDS&&
    (p_w>=6||p_h>=6)&&({2'b0,p_w}<=({2'b0,p_h}<<2))&&({2'b0,p_h}<=({2'b0,p_w}<<2))&&!union_compact_white;
 wire union_protected_arc=join_arc&&p_area>=MIN_COMPONENT&&p_seeds>=NEEDLE_MIN_SEEDS&&
              (p_w>=6||p_h>=6)&&({2'b0,p_w}<=(({2'b0,p_h}<<1)+p_h))&&
              ({2'b0,p_h}<=(({2'b0,p_w}<<1)+p_w))&&!union_compact_white;
 // V86: rescue a disconnected pair of finger rings only with a mirrored
 // compact arc at the same terminal end. Read the third descriptor serially
 // through the existing mj mux; isolated outside needles retain their veto.
 reg [5:0] repair_i,repair_j,repair_witness;
 reg [8:0] repair_x0,repair_x1;reg [7:0] repair_y0,repair_y1;
 reg repair_vertical,repair_right,repair_join,witness_eval;
 function ring_at_end;
  input [8:0] ax0,ax1,rx0,rx1;input [7:0] ay0,ay1,ry0,ry1;
  input v;
  reg [9:0] al,ar0,ar1,rl0,rl1,dist0,dist1;
  begin
   al=v?{2'b0,ay1}-{2'b0,ay0}+10'd1:{1'b0,ax1}-{1'b0,ax0}+10'd1;
   ar0=v?{2'b0,ay0}:{1'b0,ax0};ar1=v?{2'b0,ay1}:{1'b0,ax1};
   rl0=v?{2'b0,ry0}:{1'b0,rx0};rl1=v?{2'b0,ry1}:{1'b0,rx1};
   dist0=rl0>ar0?rl0-ar0:ar0-rl0;dist1=rl1>ar1?rl1-ar1:ar1-rl1;
   ring_at_end=(dist0<=6&&rl1<=ar0+(al>>2)+6)||
               (dist1<=6&&rl0+(al>>2)+6>=ar1);
  end
 endfunction
 wire [8:0] anchor_long=repair_vertical?ih:iw,anchor_short=repair_vertical?iw:ih;
 wire shaft_geometry=anchor_long>=36&&anchor_short<=20&&
   {2'b0,anchor_long}>=(({2'b0,anchor_short}<<1)+anchor_short);
 wire j_ring=c_arc[mj]&&jw>=3&&jh>=3&&jw<=24&&jh<=24;
 // One orientation selector and one end comparator, shared by initial arc
 // verification and the serial witness loop. No four parallel role/orientation
 // copies of the terminal predicate on the descriptor mux outputs.
 wire j_right=repair_vertical?c_x0[mj]>c_x1[mi]:c_y0[mj]>c_y1[mi];
 wire j_left=repair_vertical?c_x1[mj]<c_x0[mi]:c_y1[mj]<c_y0[mi];
 wire j_near=repair_vertical?(gapx<=4&&gapy==0):(gapy<=4&&gapx==0);
 wire j_terminal=ring_at_end(c_x0[mi],c_x1[mi],c_x0[mj],c_x1[mj],
                  c_y0[mi],c_y1[mi],c_y0[mj],c_y1[mj],repair_vertical);
 wire j_arc_support=cand_valid[mj]&&j_ring&&!c_blob[mj]&&j_near&&j_terminal;
 wire repair_possible=p_metal&&cand_valid[mi]&&cand_valid[mj]&&
    ((c_arc[mi]&&(jw>=36||jh>=36))||(c_arc[mj]&&(iw>=36||ih>=36)));
 wire anchor_i=!c_arc[mi];
 wire [8:0] wit_ux0=p_x0<c_x0[mj]?p_x0:c_x0[mj],wit_ux1=p_x1>c_x1[mj]?p_x1:c_x1[mj];
 wire [7:0] wit_uy0=p_y0<c_y0[mj]?p_y0:c_y0[mj],wit_uy1=p_y1>c_y1[mj]?p_y1:c_y1[mj];
 wire [9:0] wit_w={1'b0,wit_ux1}-wit_ux0+10'd1,wit_h={2'b0,wit_uy1}-wit_uy0+10'd1;
 wire [8:0] overlap_y0=c_y0[mj]>repair_y0?{1'b0,c_y0[mj]}:{1'b0,repair_y0};
 wire [8:0] overlap_y1=c_y1[mj]<repair_y1?{1'b0,c_y1[mj]}:{1'b0,repair_y1};
 wire [9:0] overlap_x0=c_x0[mj]>repair_x0?{1'b0,c_x0[mj]}:{1'b0,repair_x0};
 wire [9:0] overlap_x1=c_x1[mj]<repair_x1?{1'b0,c_x1[mj]}:{1'b0,repair_x1};
 wire witness_pair=j_arc_support&&mj!=mi&&mj!=repair_i&&mj!=repair_j&&
   (repair_right?j_left:j_right)&&
   (repair_vertical?
    (overlap_y1>=overlap_y0+9'd2&&wit_w<=44&&
     ({3'b0,wit_h}<<2)>=(({3'b0,wit_w}<<3)-wit_w)):
    (overlap_x1>=overlap_x0+10'd2&&wit_h<=44&&
     ({3'b0,wit_w}<<2)>=(({3'b0,wit_h}<<3)-wit_h)));
 wire original_join=p_metal&&(join_arc||(p_long&&!(p_arc&&p_separate)&&
                                ((p_h>=36&&p_w<=44&&({3'b0,p_h}<<2)>=(({3'b0,p_w}<<3)-p_w)&&p_gapx<=8&&p_gapy<=24&&
                                  ((p_ih>=12&&p_jh>=12&&{1'b0,p_ih}>=(p_iw<<1)&&{1'b0,p_jh}>=(p_jw<<1))||close_fragment))||
                                 (p_w>=36&&p_h<=44&&({3'b0,p_w}<<2)>=(({3'b0,p_h}<<3)-p_h)&&p_gapx<=24&&p_gapy<=8&&
                                  ((p_iw>=12&&p_jw>=12&&{1'b0,p_iw}>=(p_ih<<1)&&{1'b0,p_jw}>=(p_jh<<1))||close_fragment)))));
 wire slanted_join=linear_retry&&p_metal&&!p_ring_i&&!p_ring_j&&
   (p_long||(p_line_i&&p_line_j))&&!(p_arc&&p_separate)&&(
   (p_h>=36&&p_h>=p_w&&p_w<=80&&p_gapx<=16&&p_gapy<=24&&p_ih>=6&&p_jh>=6&&
    ({3'b0,p_ih}<<2)>=(({3'b0,p_iw}<<1)+p_iw)&&({3'b0,p_jh}<<2)>=(({3'b0,p_jw}<<1)+p_jw)&&p_gapx<=p_gapy+9'd4)||
   (p_w>=36&&p_w>=p_h&&p_h<=80&&p_gapx<=24&&p_gapy<=16&&p_iw>=6&&p_jw>=6&&
    ({3'b0,p_iw}<<2)>=(({3'b0,p_ih}<<1)+p_ih)&&({3'b0,p_jw}<<2)>=(({3'b0,p_jh}<<1)+p_jh)&&p_gapy<=p_gapx+9'd4));
 wire join_pair=original_join||slanted_join;
 wire [8:0] bw=xmax-xmin+1'b1,bh={1'b0,ymax}-{1'b0,ymin}+1'b1;
 wire vertical=bh>=bw;wire [8:0] lng=vertical?bh:bw,sht=vertical?bw:bh;
 wire [17:0] box_area=bw*bh;
 wire compact_white=({1'b0,white_area}<<1)>=area&&({2'b0,area}<<1)>=box_area&&lng<=({1'b0,sht}<<1);
 // Small bright contours may belong to one needle interrupted by a specular gap.
 // 2x2/3x2 bright glints may bridge an interrupted real arc, but area<12
 // never emits an object. Existing bounded merging and final support still apply.
 wire arc_fragment=area>=4&&area<MIN_COMPONENT&&lng>=2&&lng<=30&&sht<=8&&
                   seeds>=NEEDLE_MIN_SEEDS&&!compact_white;
 wire needle_candidate=lng<=30&&lng>=6&&area<=150&&({2'b0,area}<<1)<=box_area;
 wire protected_arc=needle_candidate&&area>=MIN_COMPONENT&&seeds>=NEEDLE_MIN_SEEDS&&
                    ({2'b0,lng}<=(({2'b0,sht}<<1)+sht))&&!compact_white;
 // Finger rings and blade profiles decide class after admission; opening must not fail an aspect gate.
 wire long_candidate=lng>=36&&sht<=MAX_TOOL_WIDTH&&({2'b0,area}<<1)<box_area;
 reg [2:0] cls;reg [4:0] out_n;
 reg [8:0] along,across,cut_pos,split_end;
 reg [5:0] row_sum,min_row;
 reg split_pending,split_vertical;
 reg tool_mode,row_prev;
 reg [8:0] row_first,row_last;
 reg [6:0] row_hits,row_run,row_max_run;
 reg [7:0] blade_rows,rail_rows;
 reg [9:0] rail_head,rail_mid,rail_tail;reg [2:0] rail_valid;
 reg [3:0] row_runs;
 reg [15:0] mid_span,mid_hits;
 reg [7:0] mid_rows,ring_rows,ring_head,ring_tail,core_rows;
 wire [10:0] rail_twice={rail_mid,1'b0},rail_ends={1'b0,rail_head}+{1'b0,rail_tail};
 wire [10:0] rail_delta=rail_twice>=rail_ends?rail_twice-rail_ends:rail_ends-rail_twice;
 wire [10:0] lng_three=({2'b0,lng}<<1)+lng;
 wire [8:0] rail_q1=lng>>2,rail_q2=lng>>1,rail_q3=lng_three[10:2];
 wire [16:0] rail_norm=lng*mid_rows;
 wire rail_profile=ring_rows<3&&(&rail_valid)&&rail_delta<=((lng>>3)+9'd8)&&
     ({3'b0,core_rows}<<3)>=(({2'b0,lng}<<2)+lng)&&rail_rows>=3&&
     (({3'b0,rail_rows}<<2)+({3'b0,rail_rows}<<1))>={3'b0,mid_rows}&&
     (({3'b0,mid_span}<<2)+{3'b0,mid_span})<={2'b0,rail_norm};

 // Keep weak connectivity for CCL and needles. Only tool profiles in a
 // cluttered frame use the independent >=64 bright support bit.
 wire hit=white_mode?raw_q[1]:(tool_mode?(clutter_frame?raw_q[3]:raw_q[2]):raw_q[0]);
 wire [7:0] ring_major=ring_head>ring_tail?ring_head:ring_tail;
 wire [7:0] ring_minor=ring_head>ring_tail?ring_tail:ring_head;
 wire core_rings=ring_major>=3&&{1'b0,ring_major}>({1'b0,ring_minor}<<1);
 wire core_thin={2'b0,lng}>=({2'b0,sht}<<2)||
                ({2'b0,lng}>=(({2'b0,sht}<<1)+sht)&&({1'b0,core_rows}<<1)>=lng);
 wire unsupported_core=clutter_frame&&!core_rings&&!core_thin&&({1'b0,core_rows}<<1)<lng;
 wire [7:0] hits_next={1'b0,row_hits}+hit;
 wire [6:0] run_next=hit?(row_run+7'd1):7'd0;
 wire [6:0] max_run_next=run_next>row_max_run?run_next:row_max_run;
 wire [10:0] blade_run14=({4'b0,max_run_next}<<4)-({4'b0,max_run_next}<<1);
 // A blade occupies a continuous solid run, normalized to length, in several central sections.
 wire thick_section=blade_run14>={2'b0,lng};
 wire open_blade=blade_rows>=3&&({4'b0,blade_rows}<<3)>={3'b0,lng};
 wire [8:0] first_next=(hit&&row_hits==0)?across:row_first;
 wire [8:0] last_next=hit?across:row_last;
 wire [8:0] span_next=(hits_next!=0)?last_next-first_next+1'b1:9'd0;
 wire [4:0] runs_next={1'b0,row_runs}+{4'b0,(hit&&!row_prev)};
 wire [11:0] along8={3'b0,along}<<3;
 wire [11:0] lng3=({3'b0,lng}<<1)+lng,lng5=({3'b0,lng}<<2)+lng;
 wire mid_band=along8>=lng3&&along8<lng5;
 wire end_band=({3'b0,along}<<2)<lng||({3'b0,along}<<2)>=lng3;
 wire [16:0] mid_box=sht*mid_rows;
 wire core_blade=({5'b0,mid_span}<<4)>=(({4'b0,mid_box}<<1)+mid_box)&&
                 ({5'b0,mid_hits}<<3)>=(({5'b0,mid_span}<<1)+mid_span);
 wire wide_blade=({5'b0,mid_span}<<2)>={4'b0,mid_box};
 wire solid_blade=({5'b0,mid_span}<<4)>=(({4'b0,mid_box}<<1)+mid_box)&&
                   ({5'b0,mid_hits}<<3)>=(({5'b0,mid_span}<<3)-mid_span);
 // This profile always reads the bright-core bit, independently of the
 // whole-frame clutter switch. Wide solid distal sections support a blade;
 // separated slender tweezer/hemostat rails cannot satisfy the run test.
 reg [6:0] seed_run,seed_max;
 reg [7:0] seed_head,seed_tail,bright_head,bright_tail;
 reg [6:0] distal_run,distal_max;
 reg [7:0] distal_head,distal_tail;
 // Independent lower-threshold solid blade profile; slender separate rails
 // still fail the five-contiguous-cell condition. Actual ring end selects
 // the opposite blade half; no screen-position or remembered class shortcut.
 wire [6:0] seed_run_next=raw_q[2]?seed_run+7'd1:7'd0;
 wire [6:0] seed_max_next=seed_run_next>seed_max?seed_run_next:seed_max;
 wire [11:0] seed_run20=({5'b0,seed_max_next}<<4)+({5'b0,seed_max_next}<<2);
 wire seed_thick=seed_max_next>=5&&seed_run20>={3'b0,lng};
 wire seeded_blade=(ring_tail>=3&&{1'b0,ring_tail}>({1'b0,ring_head}<<1)&&seed_head>=3&&({4'b0,seed_head}<<3)>={3'b0,lng})||
                   (ring_head>=3&&{1'b0,ring_head}>({1'b0,ring_tail}<<1)&&seed_tail>=3&&({4'b0,seed_tail}<<3)>={3'b0,lng});
 wire [8:0] bright_rows={1'b0,bright_head}+{1'b0,bright_tail};
 wire tool_supported=bright_head>=2&&bright_tail>=2&&({2'b0,bright_rows}<<2)>={2'b0,lng};
 wire [6:0] distal_run_next=raw_q[3]?distal_run+7'd1:7'd0;
 wire [6:0] distal_max_next=distal_run_next>distal_max?distal_run_next:distal_max;
 wire [11:0] distal_run20=({5'b0,distal_max_next}<<4)+({5'b0,distal_max_next}<<2);
 wire distal_thick=distal_max_next>=5&&distal_run20>={3'b0,lng};
 wire distal_blade=(ring_tail>=3&&{1'b0,ring_tail}>({1'b0,ring_head}<<1)&&distal_head>=3&&({4'b0,distal_head}<<3)>={3'b0,lng})||
                   (ring_head>=3&&{1'b0,ring_head}>({1'b0,ring_tail}<<1)&&distal_tail>=3&&({4'b0,distal_tail}<<3)>={3'b0,lng});
 wire [6:0] row_next={1'b0,row_sum}+raw_q[1];
 wire [10:0] along3=({2'b0,along}<<1)+along;
 wire [8:0] cut_offset=cut_pos-(vertical?{1'b0,ymin}:xmin);
 wire split_candidate=({1'b0,white_area}<<1)>=area&&({2'b0,area}<<1)>=box_area&&
                      lng>=27&&lng<=45&&sht<=26&&
                      (({3'b0,lng}<<2)+lng)>=(({3'b0,sht}<<2)+({3'b0,sht}<<1));
 // Preserve white-target splitting before needle validation at the exact
 // half-fill boundary. A white fallback that remains NEEDLE is validated next.
 wire white_cut_good=({5'b0,min_row}<<2)<=(({2'b0,sht}<<1)+sht)&&
                    cut_offset>=5&&cut_offset<=26&&lng-cut_offset>=5&&lng-cut_offset<=26;
 // A few clustered glints must not validate a large weak cloth contour.
 // Scan only a <=30x30 candidate using the existing synchronous raw RAM.
 reg needle_mode,nrow_fg,nrow_seed;
 reg [9:0] needle_hits,needle_seeds;
 reg [4:0] needle_first,needle_last;
 reg [5:0] needle_rows,needle_seed_rows;
 wire [5:0] needle_seed_span={1'b0,needle_last}-{1'b0,needle_first}+6'd1;
 wire needle_supported=needle_seeds>=NEEDLE_MIN_SEEDS&&needle_seed_rows>=3&&
     ({4'b0,needle_seed_span}<<1)>=lng&&({4'b0,needle_rows}<<1)>=lng&&
     ({4'b0,needle_seeds}<<4)>={4'b0,needle_hits};
 // Reuse the tool scan's row endpoints. Capture only three cross-sections;
 // six-bit twice-centers avoid division and preserve half-cell information.
 reg [5:0] needle_head_center,needle_mid_center,needle_tail_center;
 reg [4:0] needle_head_span,needle_mid_span,needle_tail_span;
 reg [2:0] needle_profile_valid;
 wire [8:0] needle_row_first=nrow_fg?row_first:across;
 wire [8:0] needle_row_last=raw_q[0]?across:row_last;
 wire [5:0] needle_center=needle_row_first+needle_row_last;
 wire [4:0] needle_span=needle_row_last-needle_row_first+1'b1;
 wire [6:0] needle_center_twice={needle_mid_center,1'b0};
 wire [6:0] needle_center_ends={1'b0,needle_head_center}+{1'b0,needle_tail_center};
 wire [6:0] needle_center_bend=needle_center_twice>=needle_center_ends?needle_center_twice-needle_center_ends:needle_center_ends-needle_center_twice;
 wire [5:0] needle_span_twice={needle_mid_span,1'b0};
 wire [5:0] needle_span_ends={1'b0,needle_head_span}+{1'b0,needle_tail_span};
 wire [5:0] needle_span_bend=needle_span_twice>=needle_span_ends?needle_span_twice-needle_span_ends:needle_span_ends-needle_span_twice;
 wire needle_dense=({4'b0,needle_seed_rows}<<1)>=lng;
 wire needle_profile=(&needle_profile_valid)&&(needle_center_bend>2||needle_span_bend>2);
 reg [NOBJ-1:0] tv;reg [NOBJ*9-1:0] tx0,tx1;reg [NOBJ*8-1:0] ty0,ty1;reg [NOBJ*3-1:0] tc;
 reg [NOBJ*2-1:0] trings;
 reg [41:0] tcounts;reg [3:0] err;reg [22:0] watchdog;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   best_line_score<=14'h3fff;best_direction<=0;component_direction<=0;component_line<=0;
   p_line_i<=0;p_line_j<=0;p_ring_i<=0;p_ring_j<=0;p_collinear<=0;p_direction<=0;p_cdx<=0;p_cdy<=0;saved_cross<=0;saved_corridor<=0;
   geom_index<=0;geom_x<=0;geom_y<=0;geom_return<=NADDR;
   needle_head_center<=0;needle_mid_center<=0;needle_tail_center<=0;needle_head_span<=0;needle_mid_span<=0;needle_tail_span<=0;needle_profile_valid<=0;
   needle_mode<=0;nrow_fg<=0;nrow_seed<=0;needle_hits<=0;needle_seeds<=0;needle_first<=31;needle_last<=0;needle_rows<=0;needle_seed_rows<=0;
   repair_i<=0;repair_j<=0;repair_witness<=0;repair_x0<=0;repair_x1<=0;repair_y0<=0;repair_y1<=0;repair_vertical<=0;repair_right<=0;repair_join<=0;witness_eval<=0;
   state<=IDLE;ring_ends<=0;trings<=0;objects<=0;box_x0<=0;box_x1<=0;box_y0<=0;box_y1<=0;classes<=0;counts<=0;status<=0;sequence_id<=0;
   rd_addr<=0;queue_addr<=0;read_ptr<=0;write_ptr<=0;queued<=0;queue_peak<=0;sx<=0;sy<=0;cx<=0;cy<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;
   shift_x<=0;shift_y<=0;area_shift<=0;product_bit<=0;moment_x<=0;moment_y<=0;center_mass_x<=0;center_mass_y<=0;component_bend<=0;p_bend<=0;p_independent_arcs<=0;
   neighbor<=0;area<=0;white_area<=0;seeds<=0;p_seeds<=0;cand_valid<=0;c_line<=0;c_ring_tool<=0;linear_retry<=0;linear_found<=0;nc<=0;mi<=0;mj<=1;ci<=0;pass<=0;merged<=0;
   cls<=0;out_n<=0;tv<=0;tx0<=0;tx1<=0;ty0<=0;ty1<=0;tc<=0;tcounts<=0;err<=0;watchdog<=0;
   along<=0;across<=0;cut_pos<=0;split_end<=0;row_sum<=0;min_row<=63;split_pending<=0;split_vertical<=0;
   p_x0<=0;p_x1<=0;p_y0<=0;p_y1<=0;p_w<=0;p_h<=0;p_gapx<=0;p_gapy<=0;
   p_iw<=0;p_ih<=0;p_jw<=0;p_jh<=0;p_area<=0;p_white<=0;p_metal<=0;p_long<=0;p_arc<=0;p_separate<=0;join_eval<=0;arc_eval<=0;
   level<=MIN_LEVEL;pool_count<=0;white_count<=0;weak_count<=0;read_count<=0;max_area<=0;white_mode<=0;diagnostics<=0;green_samples<=0;sparse_frames<=0;
   c_blob<=0;c_arc<=0;c_curve<=0;curve_eval<=0;slot<=0;resume_save<=0;merge_tried<=0;metal_phase<=0;white_slot<=0;white_nc<=0;frame_contamination<=0;
   tool_mode<=0;row_prev<=0;row_first<=0;row_last<=0;row_hits<=0;row_runs<=0;
   seed_run<=0;seed_max<=0;seed_head<=0;seed_tail<=0;bright_head<=0;bright_tail<=0;distal_run<=0;distal_max<=0;distal_head<=0;distal_tail<=0;mid_span<=0;mid_hits<=0;mid_rows<=0;ring_rows<=0;ring_head<=0;ring_tail<=0;core_rows<=0;blade_rows<=0;rail_rows<=0;rail_head<=0;rail_mid<=0;rail_tail<=0;rail_valid<=0;row_run<=0;row_max_run<=0;
  end else if(!enable) begin
   state<=IDLE;ring_ends<=0;objects<=0;counts<=0;status<=8;watchdog<=0;level<=MIN_LEVEL;sparse_frames<=0;
  end else begin
   if(state==IDLE&&valid&&x==0&&y==0) begin pool_count<=0;white_count<=0;weak_count<=0;max_area<=0;green_samples<=0;end
   else if(cap_we) begin
    if(cap_data[0]) pool_count<=pool_count+1'b1;
    if(cap_data[1]) white_count<=white_count+1'b1;
    if(cap_data[2:0]==3'b001) weak_count<=weak_count+1'b1;
    if(active_region&&green) green_samples<=green_samples+1'b1;
   end
   if(state!=IDLE&&state!=CAP) watchdog<=watchdog+1'b1;
   if(state==IDLE&&level>MAX_LEVEL) begin level<=RECOVER_LEVEL;sparse_frames<=0;end
   case(state)
    IDLE:begin watchdog<=0;if(valid&&x==0&&y==0) begin state<=CAP;err<=0;end end
    CAP:if(valid&&x==W-1&&y==H-1) begin
     state<=INIT;sx<=0;sy<=0;nc<=0;cand_valid<=0;c_line<=0;c_ring_tool<=0;linear_retry<=0;linear_found<=0;tv<=0;trings<=0;tcounts<=0;out_n<=0;queue_peak<=0;read_count<=0;
     // First pass reserves descriptors for compact white objects.
     white_mode<=1;metal_phase<=0;frame_contamination<=0;
     resume_save<=0;merge_tried<=0;
    end
    INIT:begin rd_addr<=addr(sx,sy);state<=IWAIT;end
    IWAIT:state<=IWAIT2;
    IWAIT2:state<=ICHECK;
    ICHECK:begin
     if(raw_q[0]) read_count<=read_count+1'b1;
     if(sx==GW-1&&sy==GH-1) begin sx<=0;sy<=0;state<=SCAN;end
     else begin if(sx==GW-1) begin sx<=0;sy<=sy+1'b1;end else sx<=sx+1'b1;state<=INIT;end
    end
    SCAN:begin rd_addr<=addr(sx,sy);state<=SWAIT;end
    SWAIT:state<=SWAIT2;
    SWAIT2:state<=SCHECK;
    SCHECK:begin
     if(seen_q) begin cx<=sx;cy<=sy;xmin<=sx;xmax<=sx;ymin<=sy;ymax<=sy;
      moment_x<={7'b0,sx};moment_y<={8'b0,sy};
      area<=1;white_area<=raw_q[1]?16'd1:16'd0;seeds<={2'b0,raw_q[2]};neighbor<=0;queued<=0;read_ptr<=0;write_ptr<=0;state<=NADDR; 
      if(!white_mode)begin geom_x<={2'b0,sx};geom_y<={3'b0,sy};geom_index<=0;geom_return<=NADDR;state<=GINIT;end
     end
     else if(sx==GW-1&&sy==GH-1) begin state<=metal_phase?MERGE:SECOND;mi<=0;mj<=1;pass<=0;merged<=0;end
     else begin if(sx==GW-1) begin sx<=0;sy<=sy+1'b1;end else sx<=sx+1'b1;state<=SCAN;end
    end
    NADDR:begin
     if(neighbor==4||!nok) begin if(neighbor==8) state<=POP;else neighbor<=neighbor+1'b1;end
     else begin rd_addr<=addr(nx[8:0],ny[7:0]);state<=NWAIT;end
    end
    NWAIT:state<=NWAIT2;
    NWAIT2:state<=NCHECK;
    NCHECK:begin
     if(seen_q&&queued==QUEUE_DEPTH) begin err[0]<=1;state<=DONE;end
     else begin
      if(seen_q) begin
       queued<=queued+1'b1;write_ptr<=(write_ptr==QUEUE_DEPTH-1)?12'd0:write_ptr+1'b1;
       if(queued+1'b1>queue_peak) queue_peak<=queued+1'b1;
       moment_x<=moment_x+nx[8:0];moment_y<=moment_y+ny[7:0];
       area<=area+1'b1;if(raw_q[1]) white_area<=white_area+1'b1;
       if(raw_q[2]&&seeds!=7) seeds<=seeds+1'b1;
       if(nx[8:0]<xmin) xmin<=nx[8:0];if(nx[8:0]>xmax) xmax<=nx[8:0];
       if(ny[7:0]<ymin) ymin<=ny[7:0];if(ny[7:0]>ymax) ymax<=ny[7:0];
      end
      if(neighbor==8) state<=POP;else begin neighbor<=neighbor+1'b1;state<=NADDR;end
      // Large/white components never consume straight-line metadata. Stop
      // measuring after cell150; their area veto is already definitive.
      if(seen_q&&!white_mode&&area<150)begin
       geom_x<=nx;geom_y<={ny[9],ny};geom_index<=0;geom_return<=neighbor==8?POP:NADDR;state<=GREAD;
      end
     end
    end
    GINIT:begin
     if(geom_index==7)state<=geom_return;else geom_index<=geom_index+1'b1;
    end
    GREAD:state<=GWRITE;
    GWRITE:begin
     if(geom_index==7)state<=geom_return;else begin geom_index<=geom_index+1'b1;state<=GREAD;end
    end
    GSCORE_READ:state<=MOMENT_PRODUCT;
    POP:if(queued==0) state<=MOMENT;else begin queue_addr<=read_ptr;read_ptr<=(read_ptr==QUEUE_DEPTH-1)?12'd0:read_ptr+1'b1;queued<=queued-1'b1;state<=PWAIT;end
    PWAIT:state<=PWAIT2;
    PWAIT2:state<=PUSE;
    PUSE:begin cx<=queue_q[8:0];cy<=queue_q[16:9];neighbor<=0;state<=NADDR;end
    SECOND:begin
     // Reuse the same RAM and queue. Keep white descriptors, scan metal next.
     metal_phase<=1;white_mode<=0;white_nc<=nc;sx<=0;sy<=0;read_count<=0;state<=INIT;
    end
    MOMENT:begin
     best_line_score<=14'h3fff;best_direction<=0;
     shift_x<={8'b0,xmin}+{8'b0,xmax};shift_y<={9'b0,ymin}+{9'b0,ymax};
     area_shift<=area[7:0];product_bit<=0;center_mass_x<=0;center_mass_y<=0;
     state<=GSCORE_READ;
    end
    MOMENT_PRODUCT:begin
     if(!white_mode&&area<=150&&projection_score<best_line_score)begin best_line_score<=projection_score;best_direction<=product_bit;end
     // Exact bounded small-arc multiplication, eight short shift/add steps.
     if(area_shift[0])begin center_mass_x<=center_mass_x+shift_x;center_mass_y<=center_mass_y+shift_y;end
     shift_x<=shift_x<<1;shift_y<=shift_y<<1;area_shift<=area_shift>>1;
     if(product_bit==7)state<=MOMENT_BIAS;else begin product_bit<=product_bit+1'b1;state<=GSCORE_READ;end
    end
    MOMENT_BIAS:begin
     component_direction<=best_direction;
     component_line<=!white_mode&&!compact_white&&area>=4&&area<=150&&lng>=9&&lng<=30&&seeds>=NEEDLE_MIN_SEEDS&&
                     best_line_score<=((({5'b0,lng}>>2)+14'd1)<<3);
     component_bend<={
       {1'b0,twice_moment_x}>({1'b0,center_mass_x}+moment_margin),
       {1'b0,center_mass_x}>({1'b0,twice_moment_x}+moment_margin),
       {1'b0,twice_moment_y}>({1'b0,center_mass_y}+moment_margin),
       {1'b0,center_mass_y}>({1'b0,twice_moment_y}+moment_margin)};
     state<=SAVE;
    end
    SAVE:begin
     if(!white_mode&&!compact_white&&area>max_area) max_area<=area;
     if(white_mode) begin
      // At least 48 white cells and six cells across reject blade glints.
      // Smaller cotton still remains eligible in the normal foreground pass.
      if(area>=48&&area<=16384&&sht>=6&&(compact_white||split_candidate)) begin
       if(nc<NCAND) begin slot<=nc;nc<=nc+1'b1;state<=INSERT;end
       else begin err[1]<=1;state<=ADVANCE;end
      end else state<=ADVANCE;
     end else if(((area>=MIN_COMPONENT&&lng>=5)||arc_fragment)&&area<=16384&&bw<GW-1&&bh<GH-1) begin
      white_slot<=0;state<=WHITE_CHECK;
     end else state<=ADVANCE;
    end
    WHITE_CHECK:begin
     // Serial center-containment veto: do not emit a second foreground flood
     // containing an independently extracted cotton/gauze core. No parallel CAM.
     if(white_slot==white_nc) begin
      if(nc<NCAND) begin slot<=nc;nc<=nc+1'b1;state<=INSERT;end
      else begin slot<=0;merge_tried<=0;state<=SLOT;end
     end else if(cand_valid[white_slot]&&
       ((c_x0[white_slot]>=xmin&&c_x1[white_slot]<=xmax&&
         c_y0[white_slot]>=ymin&&c_y1[white_slot]<=ymax&&white_area>=c_area[white_slot])||
        (compact_white&&xmin>=c_x0[white_slot]&&xmax<=c_x1[white_slot]&&
         ymin>=c_y0[white_slot]&&ymax<=c_y1[white_slot]))) begin
      if(nonwhite_count>1024&&
       (bw>(({1'b0,c_x1[white_slot]}-c_x0[white_slot]+10'd1)<<1)||
        bh>(({1'b0,c_y1[white_slot]}-c_y0[white_slot]+9'd1)<<1))) frame_contamination<=1;
      state<=ADVANCE;
     end
     else white_slot<=white_slot+1'b1;
    end
    SLOT:begin
     if(!cand_valid[slot]||(area>=MIN_COMPONENT&&c_area[slot]<MIN_COMPONENT)||(merge_tried&&seeds>=NEEDLE_MIN_SEEDS&&c_seeds[slot]<NEEDLE_MIN_SEEDS&&!c_blob[slot])) state<=INSERT;
     else if(slot==NCAND-1) begin
      if(!merge_tried) begin resume_save<=1;merge_tried<=1;mi<=0;mj<=1;pass<=0;merged<=0;state<=BEND_FETCH;end
      else begin if(area>=MIN_COMPONENT) err[1]<=1;state<=ADVANCE;end
     end else slot<=slot+1'b1;
    end
    INSERT:begin
     c_line[slot]<=component_line;c_ring_tool[slot]<=0;
     if(component_line)linear_found<=1;
     c_curve[slot]<=needle_candidate&&area>=MIN_COMPONENT&&seeds>=NEEDLE_MIN_SEEDS&&({2'b0,lng}<=({2'b0,sht}<<2))&&!compact_white;
     cand_valid[slot]<=1;c_blob[slot]<=white_mode||compact_white;c_arc[slot]<=protected_arc;
     c_x0[slot]<=xmin;c_x1[slot]<=xmax;c_y0[slot]<=ymin;c_y1[slot]<=ymax;
     c_area[slot]<=area;c_white[slot]<=white_area;c_seeds[slot]<=seeds;state<=ADVANCE;
    end
    ADVANCE:begin
     resume_save<=0;
     if(sx==GW-1&&sy==GH-1) begin state<=metal_phase?MERGE:SECOND;mi<=0;mj<=1;pass<=0;merged<=0;end
     else begin if(sx==GW-1) begin sx<=0;sy<=sy+1'b1;end else sx<=sx+1'b1;state<=SCAN;end
    end
    BEND_FETCH:state<=BEND_WAIT;
    BEND_WAIT:state<=MERGE;
    MERGE:begin
     if(nc<2) begin ci<=0;state<=LOAD;end
     else begin
      // Stage 1: read candidate descriptors and register union geometry.
      p_x0<=ux0;p_x1<=ux1;p_y0<=uy0;p_y1<=uy1;p_w<=uw;p_h<=uh;p_gapx<=gapx;p_gapy<=gapy;
      p_iw<=iw;p_ih<=ih;p_jw<=jw;p_jh<=jh;p_area<=pair_area[15:0];p_white<=c_white[mi]+c_white[mj];
      p_bend<=combine_bend(bend_i[3:0],bend_j[3:0]);
      p_independent_arcs<=c_curve[mi]&&c_curve[mj]&&bend_shared&&!bend_opposed;
      p_metal<=metal_pair;p_long<=long_seed;p_arc<=(c_arc[mi]&&(!linear_retry||!c_line[mi]||c_ring_tool[mj]))||
             (c_arc[mj]&&(!linear_retry||!c_line[mj]||c_ring_tool[mi]));p_separate<=separate_pair;
      p_seeds<=(pair_seeds>=7)?3'd7:pair_seeds[2:0];repair_join<=0;
      p_line_i<=c_line[mi];p_line_j<=c_line[mj];p_ring_i<=c_ring_tool[mi];p_ring_j<=c_ring_tool[mj];p_direction<=bend_i[6:4];
      p_cdx<=$signed({2'b0,c_x0[mi]})+$signed({2'b0,c_x1[mi]})-$signed({2'b0,c_x0[mj]})-$signed({2'b0,c_x1[mj]});
      p_cdy<=$signed({3'b0,c_y0[mi]})+$signed({3'b0,c_y1[mi]})-$signed({3'b0,c_y0[mj]})-$signed({3'b0,c_y1[mj]});
      if(c_line[mi]&&c_line[mj])state<=LINE_GEOM;else begin p_collinear<=0;state<=MDECIDE;end
     end
    end
    LINE_GEOM:begin
     saved_cross<=cross_value[11]?-cross_value:cross_value;saved_corridor<=corridor_value;state<=LINE_DECIDE;
    end
    LINE_DECIDE:begin p_collinear<=saved_cross<=saved_corridor;state<=MDECIDE;end
    MDECIDE:begin
     // Stage 2: area multiply and decision; descriptor indices remain stable.
     join_eval<=join_pair;arc_eval<=union_protected_arc;curve_eval<=union_curve;state<=MCOMMIT;
     if(!join_pair&&repair_possible) begin
      repair_i<=mi;repair_j<=mj;
      repair_vertical<=anchor_i?(ih>=iw):(jh>=jw);
      mi<=anchor_i?mi:mj;mj<=anchor_i?mj:mi;state<=RPAIR;
     end
    end
    RPAIR:begin
     if(shaft_geometry&&j_arc_support&&(j_left||j_right)) begin
      repair_x0<=c_x0[mj];repair_x1<=c_x1[mj];repair_y0<=c_y0[mj];repair_y1<=c_y1[mj];
      repair_right<=j_right;mj<=0;state<=RTEST;
     end else state<=RRETURN;
    end
    RTEST:begin witness_eval<=witness_pair;state<=RSCAN;end
    RSCAN:begin
     if(witness_eval) begin
      p_x0<=wit_ux0;p_x1<=wit_ux1;p_y0<=wit_uy0;p_y1<=wit_uy1;
      p_bend<=0;
      p_area<=p_area+c_area[mj];p_white<=p_white+c_white[mj];
      p_seeds<=7;join_eval<=1;arc_eval<=0;repair_join<=1;repair_witness<=mj;
      state<=RRETURN;
     end else if(mj==nc-1) state<=RRETURN;
     else begin mj<=mj+1'b1;state<=RTEST;end
    end
    RRETURN:begin mi<=repair_i;mj<=repair_j;state<=MCOMMIT;end
    MCOMMIT:begin
      // Stage 3: bounded-fanout descriptor writeback and iterator update.
      state<=BEND_FETCH;
      if(cand_valid[mi]&&cand_valid[mj]&&join_eval) begin
       c_line[mi]<=p_line_i&&p_line_j&&p_collinear&&!repair_join;c_ring_tool[mi]<=p_ring_i||p_ring_j;
       c_curve[mi]<=curve_eval;
       c_x0[mi]<=p_x0;c_x1[mi]<=p_x1;c_y0[mi]<=p_y0;c_y1[mi]<=p_y1;
       c_area[mi]<=p_area;c_white[mi]<=p_white;c_arc[mi]<=arc_eval;c_seeds[mi]<=p_seeds;cand_valid[mj]<=0;merged<=1;
       if(repair_join) cand_valid[repair_witness]<=0;
      end
      if(mj==nc-1) begin
       if(mi==nc-2) begin
        if((merged||(cand_valid[mi]&&cand_valid[mj]&&join_eval))&&pass<3) begin mi<=0;mj<=1;pass<=pass+1'b1;merged<=0;end
        else if(resume_save) begin slot<=0;state<=SLOT;end
        else begin ci<=0;state<=LOAD;end
       end else begin mi<=mi+1'b1;mj<=mi+2;end
      end else mj<=mj+1'b1;
    end
    LOAD:begin
     if(ci==nc) state<=DONE;
     else if(!cand_valid[ci]) ci<=ci+1'b1;
     else begin
      xmin<=c_x0[ci];xmax<=c_x1[ci];ymin<=c_y0[ci];ymax<=c_y1[ci];area<=c_area[ci];white_area<=c_white[ci];seeds<=c_seeds[ci];
      split_pending<=0;along<=0;across<=0;row_sum<=0;min_row<=63;state<=CLASSIFY;
      needle_head_center<=0;needle_mid_center<=0;needle_tail_center<=0;needle_head_span<=0;needle_mid_span<=0;needle_tail_span<=0;needle_profile_valid<=0;
   needle_mode<=0;nrow_fg<=0;nrow_seed<=0;needle_hits<=0;needle_seeds<=0;needle_first<=31;needle_last<=0;needle_rows<=0;needle_seed_rows<=0;
      tool_mode<=0;row_prev<=0;row_first<=0;row_last<=0;row_hits<=0;row_runs<=0;
      seed_run<=0;seed_max<=0;seed_head<=0;seed_tail<=0;bright_head<=0;bright_tail<=0;distal_run<=0;distal_max<=0;distal_head<=0;distal_tail<=0;mid_span<=0;mid_hits<=0;mid_rows<=0;ring_rows<=0;ring_head<=0;ring_tail<=0;core_rows<=0;blade_rows<=0;rail_rows<=0;rail_head<=0;rail_mid<=0;rail_tail<=0;rail_valid<=0;row_run<=0;row_max_run<=0;
     end
    end
    CLASSIFY:begin
     cls<=0;
     if(({1'b0,white_area}<<1)>=area&&({2'b0,area}<<1)>=box_area&&lng<=({1'b0,sht}<<1)) begin
      if(lng>=28&&sht>=18) cls<=4;       // gauze
      else if(lng<=27&&sht>=3&&area>=12) cls<=5; // cotton
     end else if(needle_candidate&&seeds>=NEEDLE_MIN_SEEDS) cls<=6; // needle
     if(area<MIN_COMPONENT||(!c_blob[ci]&&seeds<NEEDLE_MIN_SEEDS)) begin
      // Drop cloth/noise, including UNKNOWN boxes; do not exclude a fixed image region.
      ci<=ci+1'b1;state<=LOAD;
     end else if(long_candidate&&!c_blob[ci]) begin tool_mode<=1;state<=FADDR;end
     else if(needle_candidate&&seeds>=NEEDLE_MIN_SEEDS&&!compact_white&&!split_candidate) begin needle_mode<=1;state<=FADDR;end
     else if(split_candidate) state<=FADDR;else state<=EMIT;
    end
    FADDR:begin
     rd_addr<=vertical?addr(xmin+across,ymin+along):addr(xmin+along,ymin+across);state<=FWAIT;
    end
    FWAIT:state<=FWAIT2;
    FWAIT2:state<=FCHECK;
    FCHECK:begin
     if(needle_mode) begin
      if(raw_q[0]) begin
       if(!nrow_fg) row_first<=across;
       row_last<=across;
       needle_hits<=needle_hits+1'b1;
      end
      if(raw_q[2]) begin
       needle_seeds<=needle_seeds+1'b1;
       if(along<needle_first) needle_first<=along[4:0];
       if(along>needle_last) needle_last<=along[4:0];
      end
      if(across==sht-1) begin
       if(nrow_fg||raw_q[0]) begin
        needle_rows<=needle_rows+1'b1;
        if(along==0)begin needle_head_center<=needle_center;needle_head_span<=needle_span;needle_profile_valid[0]<=1;end
        if(along==(lng>>1))begin needle_mid_center<=needle_center;needle_mid_span<=needle_span;needle_profile_valid[1]<=1;end
        if(along==lng-1)begin needle_tail_center<=needle_center;needle_tail_span<=needle_span;needle_profile_valid[2]<=1;end
       end
       if(nrow_seed||raw_q[2]) needle_seed_rows<=needle_seed_rows+1'b1;
       nrow_fg<=0;nrow_seed<=0;across<=0;
       if(along==lng-1) state<=NDECIDE;else begin along<=along+1'b1;state<=FADDR;end
      end else begin
       nrow_fg<=nrow_fg||raw_q[0];nrow_seed<=nrow_seed||raw_q[2];across<=across+1'b1;state<=FADDR;
      end
     end else if(tool_mode) begin
      seed_run<=seed_run_next;seed_max<=seed_max_next;
      distal_run<=distal_run_next;distal_max<=distal_max_next;
      if(across==sht-1) begin
       if(seed_thick)begin
        if(({1'b0,along}<<1)<lng)seed_head<=seed_head+1'b1;
        else seed_tail<=seed_tail+1'b1;
       end
       if(seed_max_next!=0)begin
        if(({1'b0,along}<<1)<lng)bright_head<=bright_head+1'b1;
        else bright_tail<=bright_tail+1'b1;
       end
       seed_run<=0;seed_max<=0;
       if(distal_thick)begin
        if(({1'b0,along}<<1)<lng)distal_head<=distal_head+1'b1;
        else distal_tail<=distal_tail+1'b1;
       end
       distal_run<=0;distal_max<=0;
       if(hits_next!=0)begin
        core_rows<=core_rows+1'b1;
        if(along+9'd1>=rail_q1&&along<=rail_q1+9'd1)begin rail_head<={1'b0,first_next}+last_next;rail_valid[0]<=1;end
        if(along+9'd1>=rail_q2&&along<=rail_q2+9'd1)begin rail_mid<={1'b0,first_next}+last_next;rail_valid[1]<=1;end
        if(along+9'd1>=rail_q3&&along<=rail_q3+9'd1)begin rail_tail<={1'b0,first_next}+last_next;rail_valid[2]<=1;end
       end
       if(mid_band&&runs_next>=2)rail_rows<=rail_rows+1'b1;
       if(mid_band) begin
        mid_span<=mid_span+span_next;mid_hits<=mid_hits+hits_next;mid_rows<=mid_rows+1'b1;
       end
       if(!end_band&&thick_section) blade_rows<=blade_rows+1'b1;
       // Three foreground runs support finger-ring holes. Open jaws must not dilute ring width.
       if(end_band&&runs_next>=3&&((({3'b0,span_next}<<2)>=(({3'b0,sht}<<1)+sht))||
          (({3'b0,span_next}<<2)>={3'b0,lng}))) begin
        ring_rows<=ring_rows+1'b1;
        if(({3'b0,along}<<2)<lng) ring_head<=ring_head+1'b1;
        else ring_tail<=ring_tail+1'b1;
       end
       across<=0;row_hits<=0;row_runs<=0;row_first<=0;row_last<=0;row_prev<=0;row_run<=0;row_max_run<=0;
       if(along==lng-1) state<=FSPLIT;else begin along<=along+1'b1;state<=FADDR;end
      end else begin
       row_first<=first_next;row_last<=last_next;row_hits<=hits_next;row_runs<=(runs_next>=7)?4'd7:runs_next[3:0];row_prev<=hit;row_run<=run_next;row_max_run<=max_run_next;
       across<=across+1'b1;state<=FADDR;
      end
     end else if(across==sht-1) begin
      if(along3>=lng&&along3<=({2'b0,lng}<<1)&&row_next<min_row) begin
       min_row<=row_next;cut_pos<=(vertical?{1'b0,ymin}:xmin)+along;
      end
      across<=0;row_sum<=0;
      if(along==lng-1) state<=FSPLIT;else begin along<=along+1'b1;state<=FADDR;end
     end else begin across<=across+1'b1;row_sum<=row_next;state<=FADDR;end
    end
    NDECIDE:begin
     if(needle_supported&&(needle_dense||needle_profile)) state<=EMIT;
     else begin ci<=ci+1'b1;state<=LOAD;end
    end
    FSPLIT:begin
     if(tool_mode) begin
      c_ring_tool[ci]<=ring_rows>=3;
      if(clutter_frame) begin
       // Rings must be concentrated at one end. Texture along both ends
       // of a tweezer is not evidence for paired finger rings.
       if(core_rings) cls<=(core_blade||open_blade||distal_blade||seeded_blade)?3'd1:3'd3;
       else if(core_thin||rail_profile) cls<=2;
       else cls<=0;
      end else begin
       if(ring_rows>=3) cls<=(wide_blade||solid_blade||open_blade||distal_blade||seeded_blade)?3'd1:3'd3;
       else if({2'b0,lng}>=({2'b0,sht}<<2)||rail_profile) cls<=2;
       else cls<=0;
      end
     end else if(({5'b0,min_row}<<2)<=(({2'b0,sht}<<1)+sht)&&cut_offset>=5&&cut_offset<=26&&lng-cut_offset>=5&&lng-cut_offset<=26) begin
      cls<=5;split_pending<=1;split_vertical<=vertical;split_end<=vertical?{1'b0,ymax}:xmax;
      if(vertical) ymax<=cut_pos-1'b1;else xmax<=cut_pos-1'b1;
     end
     if(tool_mode&&(!tool_supported||unsupported_core)) begin ci<=ci+1'b1;state<=LOAD;end
     else if(!tool_mode&&cls==6&&!white_cut_good) begin
      needle_mode<=1;along<=0;across<=0;state<=FADDR;
     end else state<=EMIT;
    end
    EMIT:begin
     if(out_n<NOBJ) begin tv[out_n]<=1;tx0[out_n*9+:9]<=xmin;tx1[out_n*9+:9]<=xmax;
      ty0[out_n*8+:8]<=ymin;ty1[out_n*8+:8]<=ymax;tc[out_n*3+:3]<=cls;
      trings[out_n*2+:2]<=tool_mode&&(cls==1||cls==3)?{ring_tail>=3,ring_head>=3}:2'b00;
      tcounts[cls*6+:6]<=tcounts[cls*6+:6]+1'b1;out_n<=out_n+1'b1;end else err[1]<=1;
     if(split_pending) begin
      if(split_vertical) begin ymin<=cut_pos[7:0];ymax<=split_end[7:0];end
      else begin xmin<=cut_pos;xmax<=split_end;end
      split_pending<=0;state<=EMIT;
     end else begin ci<=ci+1'b1;state<=LOAD;end
    end
    DONE:begin
     if(linear_found&&!linear_retry&&nc>=2&&err==0)begin
      linear_retry<=1;out_n<=0;tv<=0;tcounts<=0;trings<=0;
      mi<=0;mj<=1;ci<=0;pass<=0;merged<=0;resume_save<=0;split_pending<=0;state<=BEND_FETCH;
     end else begin
     objects<=(err[0]||err[2])?{NOBJ{1'b0}}:tv;counts<=(err[0]||err[2])?42'd0:tcounts;
     ring_ends<=(err[0]||err[2])?{NOBJ*2{1'b0}}:trings;
     box_x0<=tx0;box_x1<=tx1;box_y0<=ty0;box_y1<=ty1;classes<=tc;status<=err;
     sequence_id<=sequence_id+1'b1;state<=IDLE;
     diagnostics<={{clutter_frame,6'b0,white_mode,level},{10'b0,nc},max_area,white_count,read_count,pool_count};
     // Bright gauze/cotton cannot pin the metal threshold high. The true
     // production range is 20..36; four-level steps avoid losing weak shafts.
     // A stale/out-of-range state restarts calibration instead of staying blind.
     if(level>MAX_LEVEL) begin level<=RECOVER_LEVEL;sparse_frames<=0;end
     // Only weak, non-white cells without a bright seed indicate background
     // clutter. Bright instrument contours and textile cores are excluded.
     else if(weak_count>EXCESS_POOL) begin
      sparse_frames<=0;
      if(level<MAX_LEVEL) begin
       if(level<=MAX_LEVEL-4) level<=level+8'd4;else level<=MAX_LEVEL;
      end
     end else if(weak_count<(EXCESS_POOL/2)&&nonwhite_count<=CLUTTER_POOL&&level>MIN_LEVEL) begin
      // Eight quiet frames probe one lower threshold; valid white objects
      // do not block sensitivity recovery. Tracker bridges a failed probe.
      if(sparse_frames==7) begin
       sparse_frames<=0;
       if(level>=MIN_LEVEL+4) level<=level-8'd4;else level<=MIN_LEVEL;
      end else sparse_frames<=sparse_frames+1'b1;
     end else sparse_frames<=0;
     end
    end
   endcase
   if(watchdog==23'd6000000&&state!=CAP&&state!=IDLE&&state!=DONE) begin err[2]<=1;state<=DONE;end
  end
 end
endmodule


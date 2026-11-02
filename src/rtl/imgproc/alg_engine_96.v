module alg_engine_96 #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720
)(
    input               I_clk,
    input               I_rst_n,

    input               I_tlast,
    input               I_tuser,
    input      [95:0]   I_tdata,
    input               I_tvalid,
    input               I_tready,

    // 控制(来自 alg_ctrl, 已同步到本时钟域)
    input      [2:0]    I_mode,
    input      [7:0]    I_th_bin,
    input      [7:0]    I_th_edge,
    input      [1:0]    I_strength,

    input      [7:0]    I_green_min,
    input      [7:0]    I_th_rg,
    input      [7:0]    I_th_bg,
    input      [7:0]    I_bright_min,

    output reg          O_tlast,
    output reg          O_tuser,
    output reg [95:0]   O_tdata,
    output reg          O_tvalid,
    output              O_tready,

    output reg [31:0]   O_frame_sum,
    output reg [31:0]   O_frame_cnt,
    output reg          O_frame_toggle
);

localparam integer BW      = IMG_WIDTH >> 2;
localparam [8:0]   BW_LAST = BW - 1;
localparam [9:0]   IMG_H   = IMG_HEIGHT;

assign O_tready = I_tready;

reg [2:0] mode_l;
reg [7:0] th_bin_l;
reg [7:0] th_edge_l;
reg [1:0] str_l;
reg       S_tgt_init;

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        mode_l      <= 3'd0;
        th_bin_l    <= 8'd64;
        th_edge_l   <= 8'd8;
        str_l       <= 2'd0;
        S_tgt_init  <= 1'b0;
    end else if(I_tuser || (I_tvalid && !S_tgt_init)) begin
        mode_l      <= I_mode;
        th_bin_l    <= I_th_bin;
        th_edge_l   <= I_th_edge;
        str_l       <= I_strength;
        S_tgt_init  <= 1'b1;
    end
end

reg [8:0] x_grp;
reg [9:0] y_pos;

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        x_grp <= 9'd0;
        y_pos <= 10'd0;
    end else if(I_tvalid) begin
        if(I_tuser) begin
            x_grp <= 9'd1;
            y_pos <= 10'd0;
        end else if(x_grp == BW_LAST) begin
            x_grp <= 9'd0;
            y_pos <= (y_pos == IMG_H - 1'b1) ? 10'd0 : (y_pos + 1'b1);
        end else begin
            x_grp <= x_grp + 1'b1;
        end
    end
end

wire [23:0] pix0 = I_tdata[95:72];
wire [23:0] pix1 = I_tdata[71:48];
wire [23:0] pix2 = I_tdata[47:24];
wire [23:0] pix3 = I_tdata[23:0];

function [7:0] luma_of;
    input [23:0] p;
    reg [15:0] s;
    begin
        s = ({p[23:16],6'b0} + {p[23:16],3'b0} + {p[23:16],2'b0} + p[23:16])
          + ({p[15:8], 7'b0} + {p[15:8], 4'b0} + {p[15:8], 2'b0} + {p[15:8],1'b0})
          + ({p[7:0],  4'b0} + {p[7:0],  3'b0} + {p[7:0],  2'b0} + p[7:0])
          + 16'd128;
        luma_of = s[15:8];
    end
endfunction

wire [7:0] y0 = luma_of(pix0);
wire [7:0] y1 = luma_of(pix1);
wire [7:0] y2 = luma_of(pix2);
wire [7:0] y3 = luma_of(pix3);

wire [31:0] y_word = {y3, y2, y1, y0};

wire [8:0] x_rd = (x_grp == BW_LAST) ? 9'd0 : (x_grp + 1'b1);

(* ram_style = "block" *) reg [31:0] line_buf [0:BW-1];

reg  [31:0] lb_rd;
reg  [31:0] lb_rd_d1;

reg [31:0] y_word_d;
reg [8:0]  x_grp_d;
reg        v_d;

always @(posedge I_clk) begin

    lb_rd    <= line_buf[x_rd];
    lb_rd_d1 <= lb_rd;

    y_word_d <= y_word;
    x_grp_d  <= x_grp;

    v_d      <= I_tvalid;

    if(v_d)
        line_buf[x_grp_d] <= y_word_d;
end

reg [7:0] pb0, pb1, pb2, pb3;
reg [7:0] pb_p3;

always @(posedge I_clk) begin
    if(I_tvalid) begin
        pb0   <= y0;
        pb1   <= y1;
        pb2   <= y2;
        pb3   <= y3;
        pb_p3 <= pb3;
    end
end

reg       o_first_r;
reg       o_last_r;
reg [9:0] y_out;

always @(posedge I_clk) begin
    o_first_r <= (x_grp == 9'd0);
    o_last_r  <= (x_grp == BW_LAST);
    y_out     <= y_pos;
end

wire [7:0] CB0 = o_first_r ? pb0 : pb_p3;
wire [7:0] CB1 = pb0;
wire [7:0] CB2 = pb1;
wire [7:0] CB3 = pb2;
wire [7:0] CB4 = pb3;
wire [7:0] CB5 = o_last_r ? pb3 : y0;

wire [7:0] CA1 = lb_rd_d1[7:0];
wire [7:0] CA2 = lb_rd_d1[15:8];
wire [7:0] CA3 = lb_rd_d1[23:16];
wire [7:0] CA4 = lb_rd_d1[31:24];

wire gy_on = (y_out >= 10'd1) && !o_last_r;

function [8:0] absdiff;
    input [7:0] a;
    input [7:0] b;
    begin
        absdiff = (a >= b) ? ({1'b0,a} - {1'b0,b}) : ({1'b0,b} - {1'b0,a});
    end
endfunction

function [7:0] enh_apply;
    input [7:0] v;
    input [7:0] ref_v;
    input [1:0] s;
    reg signed [11:0] d;
    reg signed [13:0] acc;
    reg signed [13:0] r;
    begin
        d   = $signed({1'b0,v}) - $signed({1'b0,ref_v});
        acc = 14'sd0;
        if(s[0]) acc = acc + d;
        if(s[1]) acc = acc + (d <<< 1);
        r   = $signed({1'b0,ref_v}) + d + (acc >>> 2);
        if(r < 14'sd0)        enh_apply = 8'd0;
        else if(r > 14'sd255) enh_apply = 8'd255;
        else                  enh_apply = r[7:0];
    end
endfunction

function seg_tool_of;
    input [23:0] p;
    input [7:0]  gmin;
    input [7:0]  trg;
    input [7:0]  tbg;
    input [7:0]  bmin;
    reg   [7:0]  r, g, b;
    reg   [8:0]  dgr, dgb;
    reg   [9:0]  bsum;
    reg          green_bg;
    begin
        r = p[23:16];
        g = p[15:8];
        b = p[7:0];
        dgr = {1'b0,g} - {1'b0,r};
        dgb = {1'b0,g} - {1'b0,b};
        bsum = {1'b0,r} + {1'b0,g} + {1'b0,b};
        green_bg = (g > gmin) && (g > r) && (dgr > {1'b0,trg}) &&
                   (g > b)    && (dgb > {1'b0,tbg});
        seg_tool_of = (~green_bg) && (bsum > {2'b0,bmin});
    end
endfunction

function [23:0] algo_pixel;
    input [2:0]  mode;
    input [23:0] rgb;
    input [7:0]  lum;
    input [8:0]  mag;
    input [7:0]  th_bin;
    input [7:0]  th_edge;
    input [1:0]  strength;
    input [7:0]  gmin;
    input [7:0]  trg;
    input [7:0]  tbg;
    input [7:0]  bmin;
    reg [7:0] r, g, b;
    reg       is_edge;
    reg       is_tool;
    begin
        is_edge = (mag >= {th_edge, 1'b0});
        is_tool = seg_tool_of(rgb, gmin, trg, tbg, bmin);
        case(mode)

            3'd0: algo_pixel = rgb;

            3'd1: algo_pixel = {lum, lum, lum};

            3'd2: algo_pixel = (lum >= th_bin) ? 24'hffffff : 24'h000000;

            3'd3: algo_pixel = is_edge ? 24'hffffff : 24'h000000;

            3'd4: begin
                if(is_edge)
                    algo_pixel = 24'h000000;
                else begin
                    r = {rgb[23:21], 5'b0} + 8'd16;
                    g = {rgb[15:13], 5'b0} + 8'd16;
                    b = {rgb[7:5],   5'b0} + 8'd16;
                    algo_pixel = {r, g, b};
                end
            end

            3'd5: begin
                r = enh_apply(rgb[23:16], 8'd128, strength);
                g = enh_apply(rgb[15:8],  8'd128, strength);
                b = enh_apply(rgb[7:0],   8'd128, strength);
                algo_pixel = { enh_apply(r, lum, strength),
                               enh_apply(g, lum, strength),
                               enh_apply(b, lum, strength) };
            end

            3'd6: algo_pixel = is_tool ? 24'h000000 : 24'hffffff;

            3'd7: algo_pixel = is_tool ? 24'hffffff : 24'h000000;
            default: algo_pixel = rgb;
        endcase
    end
endfunction

wire [8:0] gx0 = absdiff(CB2, CB0);
wire [8:0] gx1 = absdiff(CB3, CB1);
wire [8:0] gx2 = absdiff(CB4, CB2);
wire [8:0] gx3 = absdiff(CB5, CB3);

wire [8:0] gy0 = absdiff(CA1, CB1);
wire [8:0] gy1 = absdiff(CA2, CB2);
wire [8:0] gy2 = absdiff(CA3, CB3);
wire [8:0] gy3 = absdiff(CA4, CB4);

wire [8:0] mag0 = gy_on ? (gx0 + gy0) : gx0;
wire [8:0] mag1 = gy_on ? (gx1 + gy1) : gx1;
wire [8:0] mag2 = gy_on ? (gx2 + gy2) : gx2;
wire [8:0] mag3 = gy_on ? (gx3 + gy3) : gx3;

reg [95:0] rgb_d1;
always @(posedge I_clk) begin
    if(I_tvalid) rgb_d1 <= I_tdata;
end

wire [23:0] op0 = algo_pixel(mode_l, rgb_d1[95:72], CB1, mag0, th_bin_l, th_edge_l, str_l,
                             I_green_min, I_th_rg, I_th_bg, I_bright_min);
wire [23:0] op1 = algo_pixel(mode_l, rgb_d1[71:48], CB2, mag1, th_bin_l, th_edge_l, str_l,
                             I_green_min, I_th_rg, I_th_bg, I_bright_min);
wire [23:0] op2 = algo_pixel(mode_l, rgb_d1[47:24], CB3, mag2, th_bin_l, th_edge_l, str_l,
                             I_green_min, I_th_rg, I_th_bg, I_bright_min);
wire [23:0] op3 = algo_pixel(mode_l, rgb_d1[23:0],  CB4, mag3, th_bin_l, th_edge_l, str_l,
                             I_green_min, I_th_rg, I_th_bg, I_bright_min);

reg S_tlast_d, S_tuser_d, S_tvalid_d;

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        S_tlast_d  <= 1'b0;
        S_tuser_d  <= 1'b0;
        S_tvalid_d <= 1'b0;
    end else begin
        S_tlast_d  <= I_tlast;
        S_tuser_d  <= I_tuser;
        S_tvalid_d <= I_tvalid;
    end
end

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        O_tlast  <= 1'b0;
        O_tuser  <= 1'b0;
        O_tdata  <= 96'd0;
        O_tvalid <= 1'b0;
    end else begin
        O_tlast  <= S_tlast_d;
        O_tuser  <= S_tuser_d;
        O_tvalid <= S_tvalid_d;
        O_tdata  <= S_tvalid_d ? {op0, op1, op2, op3} : 96'd0;
    end
end

//   O_frame_toggle 每帧翻转一次, 供 cdc_bus_sync 跨时钟域使用。

reg [31:0] sum_acc;
reg [31:0] cnt_acc;

wire [9:0] beat_sum = {2'b0, y0} + {2'b0, y1} + {2'b0, y2} + {2'b0, y3};

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        sum_acc        <= 32'd0;
        cnt_acc        <= 32'd0;
        O_frame_sum    <= 32'd0;
        O_frame_cnt    <= 32'd0;
        O_frame_toggle <= 1'b0;
    end else if(I_tuser) begin

        O_frame_sum    <= sum_acc;
        O_frame_cnt    <= cnt_acc;
        O_frame_toggle <= ~O_frame_toggle;
        sum_acc        <= beat_sum;
        cnt_acc        <= 32'd4;
    end else if(I_tvalid) begin
        sum_acc <= sum_acc + beat_sum;
        cnt_acc <= cnt_acc + 32'd4;
    end
end

endmodule

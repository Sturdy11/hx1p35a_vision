module green_background_segment_96 #(

    parameter [7:0] GREEN_MIN_DEF  = 8'd32,
    parameter [7:0] TH_RG_DEF      = 8'd12,
    parameter [7:0] TH_BG_DEF      = 8'd12,
    parameter [7:0] BRIGHT_MIN_DEF = 8'd72,

    parameter integer SKIN_EN     = 1,
    parameter [7:0]   SKIN_RG_MIN = 8'd16,
    parameter [7:0]   SKIN_RB_MIN = 8'd20
)(
    input               I_clk,
    input               I_rst_n,

    // 数据流 (与 awb 输出同域, 无跨时钟)
    input               I_tuser,
    input               I_tvalid,
    input      [95:0]   I_tdata,

    input      [7:0]    I_green_min,
    input      [7:0]    I_th_rg,
    input      [7:0]    I_th_bg,
    input      [7:0]    I_bright_min,

    output reg          O_tuser,
    output reg          O_tvalid,
    output reg [3:0]    O_mask,

    output reg [31:0]   O_mask_cnt,
    output reg [31:0]   O_valid_cnt,

    output reg [7:0]    O_green_min,
    output reg [7:0]    O_th_rg,
    output reg [7:0]    O_th_bg,
    output reg [7:0]    O_bright_min
);

function tool_of;
    input [23:0] p;
    input [7:0]  gmin;
    input [7:0]  trg;
    input [7:0]  tbg;
    input [7:0]  bmin;
    reg   [7:0]  r, g, b;
    reg   [8:0]  dgr, dgb;
    reg   [8:0]  drg, drb;
    reg   [9:0]  bsum;
    reg          green_bg;
    reg          skin;
    begin
        r = p[23:16];
        g = p[15:8];
        b = p[7:0];
        dgr = {1'b0,g} - {1'b0,r};
        dgb = {1'b0,g} - {1'b0,b};
        drg = {1'b0,r} - {1'b0,g};
        drb = {1'b0,r} - {1'b0,b};
        bsum = {1'b0,r} + {1'b0,g} + {1'b0,b};
        green_bg = (g > gmin) && (g > r) && (dgr > {1'b0,trg}) &&
                   (g > b)    && (dgb > {1'b0,tbg});

        skin = (SKIN_EN != 0) && (!drg[8]) && (drg > {1'b0,SKIN_RG_MIN}) &&
                             (!drb[8]) && (drb > {1'b0,SKIN_RB_MIN});
        tool_of  = (~green_bg) && (~skin) && (bsum > {2'b0,bmin});
    end
endfunction

function [2:0] pop4;
    input [3:0] v;
    begin
        pop4 = {2'b0,v[0]} + {2'b0,v[1]} + {2'b0,v[2]} + {2'b0,v[3]};
    end
endfunction

wire [3:0] S_tool = {
    tool_of(I_tdata[95:72], O_green_min, O_th_rg, O_th_bg, O_bright_min),
    tool_of(I_tdata[71:48], O_green_min, O_th_rg, O_th_bg, O_bright_min),
    tool_of(I_tdata[47:24], O_green_min, O_th_rg, O_th_bg, O_bright_min),
    tool_of(I_tdata[23:0],  O_green_min, O_th_rg, O_th_bg, O_bright_min)
};
wire [2:0] S_pop = pop4(S_tool);

reg [31:0] mask_acc, valid_acc;

always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        O_tuser      <= 1'b0;
        O_tvalid     <= 1'b0;
        O_mask       <= 4'd0;
        O_mask_cnt   <= 32'd0;
        O_valid_cnt  <= 32'd0;
        O_green_min  <= GREEN_MIN_DEF;
        O_th_rg      <= TH_RG_DEF;
        O_th_bg      <= TH_BG_DEF;
        O_bright_min <= BRIGHT_MIN_DEF;
        mask_acc     <= 32'd0;
        valid_acc    <= 32'd0;
    end else begin

        if (I_tuser) begin
            O_green_min  <= I_green_min;
            O_th_rg      <= I_th_rg;
            O_th_bg      <= I_th_bg;
            O_bright_min <= I_bright_min;
        end

        O_tuser  <= I_tuser;
        O_tvalid <= I_tvalid;
        O_mask   <= I_tvalid ? S_tool : 4'd0;

        if (I_tuser) begin
            O_mask_cnt  <= mask_acc;
            O_valid_cnt <= valid_acc;
            mask_acc    <= I_tvalid ? {29'd0, S_pop} : 32'd0;
            valid_acc   <= I_tvalid ? 32'd1          : 32'd0;
        end else if (I_tvalid) begin
            mask_acc  <= mask_acc  + {29'd0, S_pop};
            valid_acc <= valid_acc + 32'd1;
        end
    end
end

endmodule

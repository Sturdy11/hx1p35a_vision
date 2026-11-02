module dilation_3x3_96 #(
    parameter integer IMG_WIDTH = 1280,
    parameter integer IMG_HEIGHT = 720
)(
    input wire I_clk,
    input wire I_rst_n,
    input wire I_tuser,
    input wire I_tvalid,
    input wire [95:0] I_tdata,
    input wire I_enable,
    output reg O_tuser,
    output reg O_tvalid,
    output reg [95:0] O_tdata
);
localparam integer BEATS = IMG_WIDTH / 4;
localparam integer LAST = BEATS - 1;

// Separate physical banks keep synthesis from building a dynamic 2-D RAM mux.
reg [3:0] hit_mem0 [0:BEATS-1];
reg [3:0] hit_mem1 [0:BEATS-1];
reg [3:0] hit_mem2 [0:BEATS-1];
reg [1:0] cur_bank, prev_bank, prev2_bank;
reg [9:0] in_beat;
reg [10:0] in_row;
reg frame_active;
reg marker_pending;
reg pending_valid;
reg flush_active;
reg [9:0] flush_beat;
reg [1:0] pending_top_bank, pending_mid_bank, pending_bot_bank;
reg [3:0] pending_bot_last;
reg [1:0] flush_top_bank, flush_mid_bank;
integer effective_row, effective_beat;
integer i;
integer top_bank_i, mid_bank_i, bot_bank_i;
reg [3:0] cur_hit;
reg [3:0] top_l, top_c, top_r;
reg [3:0] mid_l, mid_c, mid_r;
reg [3:0] bot_l, bot_c, bot_r;
reg [3:0] out_hit;

function [3:0] raw_hit;
    input [95:0] d;
    integer q;
    begin
        for (q=0; q<4; q=q+1)
            raw_hit[q] = (d[95-q*24 -: 8] >= 8'h80);
    end
endfunction

function [95:0] hit_rgb;
    input [3:0] h;
    integer q;
    begin
        hit_rgb = 96'd0;
        for (q=0; q<4; q=q+1)
            hit_rgb[95-q*24 -: 24] = h[q] ? 24'hffffff : 24'h000000;
    end
endfunction

function [3:0] mem_hit;
    input integer bank_i;
    input integer beat_i;
    begin
        if ((bank_i < 0) || (bank_i > 2) ||
            (beat_i < 0) || (beat_i >= BEATS))
            mem_hit = 4'd0;
        else if (bank_i == 0)
            mem_hit = hit_mem0[beat_i];
        else if (bank_i == 1)
            mem_hit = hit_mem1[beat_i];
        else
            mem_hit = hit_mem2[beat_i];
    end
endfunction

function [3:0] dilate_beat;
    input [3:0] tl, tc, tr;
    input [3:0] ml, mc, mr;
    input [3:0] bl, bc, br;
    integer q;
    begin
        for (q=0; q<4; q=q+1)
            dilate_beat[q] =
                ((q==0 ? tl[3] : tc[q-1]) | tc[q] | (q==3 ? tr[0] : tc[q+1]) |
                 (q==0 ? ml[3] : mc[q-1]) | mc[q] | (q==3 ? mr[0] : mc[q+1]) |
                 (q==0 ? bl[3] : bc[q-1]) | bc[q] | (q==3 ? br[0] : bc[q+1]));
    end
endfunction

reg bypass_marker_pending;
always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        O_tuser <= 1'b0;
        O_tvalid <= 1'b0;
        O_tdata <= 96'd0;
        cur_bank <= 2'd0;
        prev_bank <= 2'd0;
        prev2_bank <= 2'd0;
        in_beat <= 10'd0;
        in_row <= 11'd0;
        frame_active <= 1'b0;
        marker_pending <= 1'b0;
        pending_valid <= 1'b0;
        flush_active <= 1'b0;
        flush_beat <= 10'd0;
        pending_top_bank <= 2'd0;
        pending_mid_bank <= 2'd0;
        pending_bot_bank <= 2'd0;
        pending_bot_last <= 4'd0;
        flush_top_bank <= 2'd0;
        flush_mid_bank <= 2'd0;
        bypass_marker_pending <= 1'b0;
        hit_mem0[0] <= 4'd0;
        hit_mem1[0] <= 4'd0;
        hit_mem2[0] <= 4'd0;
    end else begin
        O_tuser <= 1'b0;
        O_tvalid <= 1'b0;

        if (!I_enable) begin
            if (I_tuser)
                bypass_marker_pending <= 1'b1;
            if (I_tvalid) begin
                O_tvalid <= 1'b1;
                O_tdata <= I_tdata;
                if (bypass_marker_pending || I_tuser) begin
                    O_tuser <= 1'b1;
                    bypass_marker_pending <= 1'b0;
                end
            end
        end else begin

            effective_row = I_tuser ? 0 : in_row;
            effective_beat = I_tuser ? 0 : in_beat;
            if (I_tuser) begin
                frame_active <= 1'b1;
                marker_pending <= 1'b1;
                in_beat <= 10'd0;
                in_row <= 11'd0;
            end

            if (pending_valid) begin
                top_l = mem_hit(pending_top_bank, LAST-1);
                top_c = mem_hit(pending_top_bank, LAST);
                top_r = 4'd0;
                mid_l = mem_hit(pending_mid_bank, LAST-1);
                mid_c = mem_hit(pending_mid_bank, LAST);
                mid_r = 4'd0;
                bot_l = mem_hit(pending_bot_bank, LAST-1);
                bot_c = pending_bot_last;
                bot_r = 4'd0;
                out_hit = dilate_beat(top_l,top_c,top_r,
                                      mid_l,mid_c,mid_r,
                                      bot_l,bot_c,bot_r);
                O_tdata <= hit_rgb(out_hit);
                O_tvalid <= 1'b1;
                pending_valid <= 1'b0;
            end else if (flush_active) begin

                top_l = mem_hit(flush_top_bank, flush_beat-1);
                top_c = mem_hit(flush_top_bank, flush_beat);
                top_r = mem_hit(flush_top_bank, flush_beat+1);
                mid_l = mem_hit(flush_mid_bank, flush_beat-1);
                mid_c = mem_hit(flush_mid_bank, flush_beat);
                mid_r = mem_hit(flush_mid_bank, flush_beat+1);
                out_hit = dilate_beat(top_l,top_c,top_r,
                                      mid_l,mid_c,mid_r,
                                      4'd0,4'd0,4'd0);
                O_tdata <= hit_rgb(out_hit);
                O_tvalid <= 1'b1;
                if (flush_beat == LAST) begin
                    flush_active <= 1'b0;
                    flush_beat <= 10'd0;
                end else begin
                    flush_beat <= flush_beat + 1'b1;
                end
            end

            if (I_tvalid && (frame_active || I_tuser)) begin
                cur_hit = raw_hit(I_tdata);
                if (cur_bank == 0)
                    hit_mem0[in_beat] <= cur_hit;
                else if (cur_bank == 1)
                    hit_mem1[in_beat] <= cur_hit;
                else
                    hit_mem2[in_beat] <= cur_hit;

                if ((in_row >= 1) && (in_beat >= 1) && !pending_valid && !flush_active) begin
                    top_bank_i = (in_row >= 2) ? prev2_bank : -1;
                    mid_bank_i = prev_bank;
                    bot_bank_i = cur_bank;
                    top_l = mem_hit(top_bank_i, in_beat-2);
                    top_c = mem_hit(top_bank_i, in_beat-1);
                    top_r = mem_hit(top_bank_i, in_beat);
                    mid_l = mem_hit(mid_bank_i, in_beat-2);
                    mid_c = mem_hit(mid_bank_i, in_beat-1);
                    mid_r = mem_hit(mid_bank_i, in_beat);
                    bot_l = mem_hit(bot_bank_i, in_beat-2);
                    bot_c = mem_hit(bot_bank_i, in_beat-1);
                    bot_r = cur_hit;
                    out_hit = dilate_beat(top_l,top_c,top_r,
                                          mid_l,mid_c,mid_r,
                                          bot_l,bot_c,bot_r);
                    O_tdata <= hit_rgb(out_hit);
                    O_tvalid <= 1'b1;
                    if (marker_pending) begin
                        O_tuser <= 1'b1;
                        marker_pending <= 1'b0;
                    end
                end

                if (in_beat == LAST) begin

                    if (in_row >= 1) begin
                        pending_valid <= 1'b1;
                        pending_top_bank <= (in_row >= 2) ? prev2_bank : 2'd3;
                        pending_mid_bank <= prev_bank;
                        pending_bot_bank <= cur_bank;
                        pending_bot_last <= cur_hit;
                    end
                    if (in_row == IMG_HEIGHT-1) begin
                        flush_active <= 1'b1;
                        flush_beat <= 10'd0;
                        flush_top_bank <= prev_bank;
                        flush_mid_bank <= cur_bank;
                    end
                    in_beat <= 10'd0;
                    in_row <= in_row + 1'b1;
                    prev2_bank <= prev_bank;
                    prev_bank <= cur_bank;
                    cur_bank <= (cur_bank == 2) ? 2'd0 : cur_bank + 1'b1;
                end else begin
                    in_beat <= in_beat + 1'b1;
                end
            end
        end
    end
end
endmodule

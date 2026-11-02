/*****************************************************************
Company : MiLianKe Electronic Technology Co., Ltd.
WebSite:https://www.milianke.com
TechWeb:https://www.uisrc.com
tmall-shop:https://milianke.tmall.com
jd-shop:https://milianke.jd.com
taobao-shop: https://milianke.taobao.com
Description: 
The reference demo provided by Milianke is only used for learning. 
We cannot ensure that the demo itself is free of bugs, so users 
should be responsible for the technical problems and consequences
caused by the use of their own products.
@Author      :   XiaoQingquan 
@Time        :   2024/11 
version:     :   
@Description :   
*****************************************************************/
`timescale 1ns/1ns

module mipi_to_raw_converter 
(
    input                          I_clk   ,
    input                          I_rst_n ,

    input   [39:0]                 I_raw_tdata ,
    input   [ 9:0]                 I_raw_tdest ,
    input                          I_raw_tlast ,
    input                          I_raw_tvalid,
    input                          I_raw_tuser ,
    output                         I_raw_tready,
    
    // ���RAW10����
    output  [31:0]                 O_raw_tdata ,
    output                         O_raw_tlast ,
    output                         O_raw_tvalid,
    output                         O_raw_tuser ,
    input                          O_raw_tready
);
    reg            I_tlast_r0;
    reg            I_tuser_r0;

    reg            I_tvalid_r0;
    reg    [31:0]  raw_data_r0;

    //--------------------------------------------------------------------------
    // build17 fix (1/4): black-level correction (BLC), saturating.
    //
    //   This module is the ONLY place in the whole data path where RAW10 is
    //   converted to RAW8 (top 8 bits, i.e. >>2).  Up to build16 that was a
    //   plain truncation with NO black-level subtraction, so the sensor
    //   pedestal (~64 LSB in the 10-bit domain) survived as a ~16/255 grey
    //   floor: washed out, foggy, low contrast -- the direct cause of the
    //   "not vivid enough" symptom.  No downstream saturation stretch can
    //   recover contrast that was never there.
    //
    //   BLACK_LEVEL = 64 = 0x40 is the typical SC500 10-bit dark level.
    //   Write 0 to restore the exact build16 behaviour (pure truncation).
    //   v <= BLACK_LEVEL saturates to 0 instead of wrapping unsigned, so the
    //   darkest pixels cannot blow up into white speckles.
    //
    //   Byte order is preserved bit-for-bit versus the old expression:
    //     out[31:24] <- tdata[9:0]    out[23:16] <- tdata[19:10]
    //     out[15:8]  <- tdata[29:20]  out[7:0]   <- tdata[39:30]
    //--------------------------------------------------------------------------
    localparam [9:0] BLACK_LEVEL = 10'd64;

    function [7:0] raw10_to_raw8;
        input [9:0] v;
        begin
            raw10_to_raw8 = (v > BLACK_LEVEL) ? ((v - BLACK_LEVEL) >> 2) : 8'd0;
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            raw_data_r0 <= 0;
        else if(I_raw_tvalid)begin
            raw_data_r0 <= { raw10_to_raw8(I_raw_tdata[9:0]),
                             raw10_to_raw8(I_raw_tdata[19:10]),
                             raw10_to_raw8(I_raw_tdata[29:20]),
                             raw10_to_raw8(I_raw_tdata[39:30]) };
        end 
    end



    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)begin
            {I_tlast_r0,I_tuser_r0,I_tvalid_r0} <= 0;
        end
        else begin
            I_tlast_r0  <= I_raw_tlast;
            I_tuser_r0  <= I_raw_tuser;
            I_tvalid_r0 <= I_raw_tvalid;
        end
    end
    

    assign  O_raw_tlast  = I_tlast_r0;   
    assign  O_raw_tuser  = I_tuser_r0;   
    assign  O_raw_tvalid = I_tvalid_r0;

    assign  O_raw_tdata  = raw_data_r0;
    
    assign  I_raw_tready = O_raw_tready;


endmodule



module mask_close_3x3_96 #(
    parameter integer IMG_WIDTH  = 1280,
    parameter integer IMG_HEIGHT = 720,
    parameter integer CLOSE_EN   = 1,

    parameter integer MORPH_EN   = 0
)(
    input               I_clk,
    input               I_rst_n,
    input               I_tuser,
    input               I_tvalid,
    input      [3:0]    I_mask,

    output              O_tuser,
    output              O_tvalid,
    output     [95:0]   O_tdata,

    output reg [31:0]   O_closed_cnt
);

function [95:0] render;
    input [3:0] m;
    begin
        render = { m[3] ? 24'hffffff : 24'h000000,
                   m[2] ? 24'hffffff : 24'h000000,
                   m[1] ? 24'hffffff : 24'h000000,
                   m[0] ? 24'hffffff : 24'h000000 };
    end
endfunction

wire [95:0] S_d1_in = render(I_mask);

wire [95:0] S_d1_out;
wire        S_d1_tuser, S_d1_tvalid;

dilation_3x3_96 #(
    .IMG_WIDTH (IMG_WIDTH ),
    .IMG_HEIGHT(IMG_HEIGHT)
) u_mask_dilate (
    .I_clk   (I_clk    ),
    .I_rst_n (I_rst_n  ),
    .I_tuser (I_tuser  ),
    .I_tvalid(I_tvalid ),
    .I_tdata (S_d1_in  ),
    .I_enable(MORPH_EN ),
    .O_tuser (S_d1_tuser),
    .O_tvalid(S_d1_tvalid),
    .O_tdata (S_d1_out )
);

generate
if ((MORPH_EN == 1) && (CLOSE_EN == 1)) begin : g_erode
    wire [95:0] S_d2_out;
    wire        S_d2_tuser, S_d2_tvalid;

    dilation_3x3_96 #(
        .IMG_WIDTH (IMG_WIDTH ),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) u_mask_erode (
        .I_clk   (I_clk     ),
        .I_rst_n (I_rst_n   ),
        .I_tuser (S_d1_tuser),
        .I_tvalid(S_d1_tvalid),
        .I_tdata (~S_d1_out ),
        .I_enable(1'b1      ),
        .O_tuser (S_d2_tuser),
        .O_tvalid(S_d2_tvalid),
        .O_tdata (S_d2_out  )
    );

    assign O_tdata  = ~S_d2_out;
    assign O_tvalid = S_d2_tvalid;
    assign O_tuser  = S_d2_tuser;
end else begin : g_no_erode
    assign O_tdata  = S_d1_out;
    assign O_tvalid = S_d1_tvalid;
    assign O_tuser  = S_d1_tuser;
end
endgenerate

wire [2:0] S_pop = {2'b0,O_tdata[95]} + {2'b0,O_tdata[71]} +
                   {2'b0,O_tdata[47]} + {2'b0,O_tdata[23]};

reg [31:0] cnt_acc, cnt_lat;

always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        cnt_acc    <= 32'd0;
        cnt_lat    <= 32'd0;
        O_closed_cnt <= 32'd0;
    end else if (O_tuser) begin

        O_closed_cnt <= cnt_acc;
        cnt_acc      <= O_tvalid ? {29'd0, S_pop} : 32'd0;
    end else if (O_tvalid) begin
        cnt_acc <= cnt_acc + {29'd0, S_pop};
    end
end

endmodule

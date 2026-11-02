module color_enhance #(

    parameter [9:0] R_GAIN = 10'd256,
    parameter [9:0] G_GAIN = 10'd256,
    parameter [9:0] B_GAIN = 10'd256,

    parameter [9:0] SAT_C  = 10'd323,
    parameter [9:0] SAT_Y  = 10'd51,
    parameter [11:0] SAT_BIAS = 12'd1920,

    parameter [9:0] SAT_D  = SAT_C - SAT_Y,

    parameter [9:0] HI_KNEE = 10'd232
)(
    input               I_clk,
    input               I_rst_n,

    input               I_tlast,
    input               I_tuser,
    input       [95:0]  I_tdata,
    input               I_tvalid,
    output              I_tready,

    input       [10:0]  I_gain,

    output reg          O_tlast,
    output reg          O_tuser,
    output reg  [95:0]  O_tdata,
    output reg          O_tvalid,
    input               O_tready
);

    assign I_tready = O_tready;

    function [7:0] gain_ch;
        input [7:0] c;
        input [9:0] g;
        reg [17:0] m;
        integer b;
        begin
            m = 18'd0;

            for(b = 0; b < 10; b = b + 1)
                if(g[b] == 1'b1)
                    m = m + ({10'd0, c} << b);
            gain_ch = (m[17:8] > 10'd255) ? 8'd255 : m[17:8];
        end
    endfunction

    function [23:0] gain_pix;
        input [23:0] p;
        begin
            gain_pix = { gain_ch(p[23:16], R_GAIN),
                         gain_ch(p[15:8],  G_GAIN),
                         gain_ch(p[7:0],   B_GAIN) };
        end
    endfunction

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

    function [7:0] gain_y;
        input [7:0]  y;
        input [10:0] g;
        reg [18:0] m;
        begin

            m = y * g;
            gain_y = (m[18:8] > 11'd255) ? 8'd255 : m[18:8];
        end
    endfunction

    localparam [18:0] S_OFF     = 19'd98304;
    localparam [18:0] S_HI      = S_OFF + 19'd65280;
    localparam [18:0] S_KNEE    = S_OFF + (HI_KNEE * 19'd256);
    localparam [18:0] S_BIASK   = S_OFF - (SAT_D * 19'd256);
    localparam [18:0] S_SOFTADJ = S_OFF - (HI_KNEE * 19'd256);
    localparam [17:0] D_OFF     = (SAT_D * 19'd256);
    localparam [9:0]  S_OFF8    = S_OFF[17:8];

    function [17:0] const_mul;
        input [7:0]  x;
        input [9:0]  k;
        reg  [17:0]  m;
        integer b;
        begin
            m = 18'd0;
            for(b = 0; b < 10; b = b + 1)
                if(k[b] == 1'b1)
                    m = m + ({10'd0, x} << b);
            const_mul = m;
        end
    endfunction

    function [7:0] ch_enh;
        input [7:0] c;
        input [7:0] y;
        input [7:0] yd;
        reg [17:0] uC;
        reg [17:0] vB;
        reg [17:0] uD;
        reg [18:0] s;
        reg [9:0]  lin;
        reg [18:0] sof;
        begin
            uC = const_mul(c, SAT_C);
            vB = const_mul(y, SAT_Y) + SAT_BIAS;
            uD = const_mul(yd, SAT_D) + D_OFF;
            s  = ({1'b0, uC} + {1'b0, uD} + S_BIASK) - {1'b0, vB};
            lin = s[17:8] - S_OFF8;
            sof = (s - S_SOFTADJ) >> 9;
            ch_enh = (s <= S_OFF)  ? 8'd0       :
                     ((s >= S_HI)  ? 8'd255     :
                     ((s >= S_KNEE) ? sof[7:0]  : lin[7:0]));
        end
    endfunction

    function [23:0] chan_enh;
        input [23:0] p;
        input [7:0]  y;
        input [7:0]  yd;
        begin
            chan_enh = { ch_enh(p[23:16], y, yd),
                         ch_enh(p[15:8],  y, yd),
                         ch_enh(p[7:0],   y, yd) };
        end
    endfunction

    reg [95:0] p1;
    reg        t1_last, t1_user, t1_valid;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            p1       <= 96'd0;
            t1_last  <= 1'b0;
            t1_user  <= 1'b0;
            t1_valid <= 1'b0;
        end else begin
            p1 <= { gain_pix(I_tdata[95:72]), gain_pix(I_tdata[71:48]),
                    gain_pix(I_tdata[47:24]), gain_pix(I_tdata[23:0])  };
            t1_last  <= I_tlast;
            t1_user  <= I_tuser;
            t1_valid <= I_tvalid;
        end
    end

    reg [95:0] p2;
    reg [31:0] y2;
    reg        t2_last, t2_user, t2_valid;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            p2       <= 96'd0;
            y2       <= 32'd0;
            t2_last  <= 1'b0;
            t2_user  <= 1'b0;
            t2_valid <= 1'b0;
        end else begin
            p2 <= p1;
            y2 <= { luma_of(p1[95:72]), luma_of(p1[71:48]),
                    luma_of(p1[47:24]), luma_of(p1[23:0])  };
            t2_last  <= t1_last;
            t2_user  <= t1_user;
            t2_valid <= t1_valid;
        end
    end

    reg [95:0] p3;
    reg [31:0] y3;
    reg [31:0] yd3;
    reg        t3_last, t3_user, t3_valid;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            p3       <= 96'd0;
            y3       <= 32'd0;
            yd3      <= 32'd0;
            t3_last  <= 1'b0;
            t3_user  <= 1'b0;
            t3_valid <= 1'b0;
        end else begin
            p3  <= p2;
            y3  <= y2;
            yd3 <= { (gain_y(y2[31:24], I_gain) - y2[31:24]),
                     (gain_y(y2[23:16], I_gain) - y2[23:16]),
                     (gain_y(y2[15:8],  I_gain) - y2[15:8] ),
                     (gain_y(y2[7:0],   I_gain) - y2[7:0]  ) };
            t3_last  <= t2_last;
            t3_user  <= t2_user;
            t3_valid <= t2_valid;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_tlast  <= 1'b0;
            O_tuser  <= 1'b0;
            O_tvalid <= 1'b0;
            O_tdata  <= 96'd0;
        end else begin
            O_tlast  <= t3_last;
            O_tuser  <= t3_user;
            O_tvalid <= t3_valid;
            O_tdata  <= t3_valid ? { chan_enh(p3[95:72], y3[31:24], yd3[31:24]),
                                     chan_enh(p3[71:48], y3[23:16], yd3[23:16]),
                                     chan_enh(p3[47:24], y3[15:8],  yd3[15:8] ),
                                     chan_enh(p3[23:0],  y3[7:0],   yd3[7:0]  ) }
                                 : 96'd0;
        end
    end

endmodule

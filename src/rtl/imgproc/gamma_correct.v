//   延迟 1 拍, tlast/tuser/tvalid 同步延迟 1 拍。

module gamma_correct #(

    parameter BYPASS = 1'b0
)(
    input               I_clk,
    input               I_rst_n,

    input               I_tlast,
    input               I_tuser,
    input       [95:0]  I_tdata,
    input               I_tvalid,
    output              I_tready,

    output reg          O_tlast,
    output reg          O_tuser,
    output reg  [95:0]  O_tdata,
    output reg          O_tvalid,
    input               O_tready
);

    assign I_tready = O_tready;

    wire [95:0] S_gam;

    gamma_lut u_gam_p0r (.I_addr(I_tdata[95:88]), .O_data(S_gam[95:88]));
    gamma_lut u_gam_p0g (.I_addr(I_tdata[87:80]), .O_data(S_gam[87:80]));
    gamma_lut u_gam_p0b (.I_addr(I_tdata[79:72]), .O_data(S_gam[79:72]));

    gamma_lut u_gam_p1r (.I_addr(I_tdata[71:64]), .O_data(S_gam[71:64]));
    gamma_lut u_gam_p1g (.I_addr(I_tdata[63:56]), .O_data(S_gam[63:56]));
    gamma_lut u_gam_p1b (.I_addr(I_tdata[55:48]), .O_data(S_gam[55:48]));

    gamma_lut u_gam_p2r (.I_addr(I_tdata[47:40]), .O_data(S_gam[47:40]));
    gamma_lut u_gam_p2g (.I_addr(I_tdata[39:32]), .O_data(S_gam[39:32]));
    gamma_lut u_gam_p2b (.I_addr(I_tdata[31:24]), .O_data(S_gam[31:24]));

    gamma_lut u_gam_p3r (.I_addr(I_tdata[23:16]), .O_data(S_gam[23:16]));
    gamma_lut u_gam_p3g (.I_addr(I_tdata[15:8] ), .O_data(S_gam[15:8] ));
    gamma_lut u_gam_p3b (.I_addr(I_tdata[7:0]  ), .O_data(S_gam[7:0]  ));

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_tlast  <= 1'b0;
            O_tuser  <= 1'b0;
            O_tvalid <= 1'b0;
            O_tdata  <= 96'd0;
        end else begin
            O_tlast  <= I_tlast;
            O_tuser  <= I_tuser;
            O_tvalid <= I_tvalid;
            O_tdata  <= I_tvalid ? (BYPASS ? I_tdata : S_gam) : 96'd0;
        end
    end

endmodule

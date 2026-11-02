// SW1 A4: count audit; SW2 B4: detection, both active low.
// KEY1/KEY2: next/previous mode; KEY3: OSD; KEY4: short selects, long requests baseline.
// Modes: enhance, grayscale, binary, segmentation, Sobel, original.
module alg_ctrl111 #(parameter KEY_DEBOUNCE=1000000,KEY_LONG=100000000) (
    input               I_clk,
    input               I_rst_n,

    input      [3:0]    I_key_n,          // 原始按键输入, 低有效
    input      [3:0]    I_sw,

    output reg [2:0]    O_mode,
    output reg [3:0]    O_param,
    output reg [7:0]    O_th_bin,
    output reg [7:0]    O_th_edge,
    output reg [1:0]    O_strength,
    output reg [7:0]    O_th_r,
    output reg [7:0]    O_th_d,
    output reg          O_osd_en,
    output reg          O_detect_en,
    output reg          O_dilation_en,
    output reg          O_debug_raw,

    // 控制总线 (供 cdc_bus_sync 使用)
    output reg [47:0]   O_ctrl_bus,
    output reg          O_ctrl_toggle
);

localparam MODE_NUM = 3'd6;

localparam [7:0] GREEN_MIN_BASE = 8'd32;
localparam [7:0] TH_RG_BASE     = 8'd12;

wire k1, k2, k3, k4, k4_long;
reg audit_request,baseline_request;

key_remove_shakes u_key1 (.I_clk(I_clk), .I_rst_n(I_rst_n), .I_key_in(I_key_n[0]), .O_key_trig_out(k1));
key_remove_shakes u_key2 (.I_clk(I_clk), .I_rst_n(I_rst_n), .I_key_in(I_key_n[1]), .O_key_trig_out(k2));
key_remove_shakes u_key3 (.I_clk(I_clk), .I_rst_n(I_rst_n), .I_key_in(I_key_n[2]), .O_key_trig_out(k3));
key_action80 #(.DEBOUNCE_CYCLES(KEY_DEBOUNCE),.LONG_CYCLES(KEY_LONG)) u_key4 (.clk(I_clk),.rst_n(I_rst_n),.key_n(I_key_n[3]),.short_pulse(k4),.long_pulse(k4_long));

reg [3:0] sw_s1, sw_s2;
always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        sw_s1 <= 4'h0;
        sw_s2 <= 4'h0;
    end else begin
        sw_s1 <= ~I_sw;         // 低有效按键 -> 高有效档位
        sw_s2 <= sw_s1;
    end
end

reg [15:0] sw_cnt;
reg [3:0]  sw_commit;
wire [3:0] sw_param = {sw_commit[3:2], 2'b00};

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        sw_cnt    <= 16'd0;
        sw_commit <= 4'd0;
    end else if(sw_s2 == sw_commit) begin
        sw_cnt <= 16'd0;
    end else if(sw_cnt == 16'hffff) begin
        sw_cnt    <= 16'd0;
        sw_commit <= sw_s2;
    end else begin
        sw_cnt <= sw_cnt + 16'd1;
    end
end

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        O_mode      <= 3'd0;
        audit_request<=0;baseline_request<=0;
        O_osd_en    <= 1'b1;
        O_detect_en <= 1'b0;
        O_dilation_en <= 1'b1;
        O_debug_raw <= 1'b0;
    end else begin
        if(k1)
            O_mode <= (O_mode == MODE_NUM - 1'b1) ? 3'd0 : (O_mode + 1'b1);
        else if(k2)
            O_mode <= (O_mode == 3'd0) ? (MODE_NUM - 1'b1) : (O_mode - 1'b1);

        if(k4) audit_request<=~audit_request;
        if(k4_long&&sw_commit[0]&&sw_commit[1])baseline_request<=~baseline_request;
        if(k3) O_osd_en    <= ~O_osd_en;
        O_detect_en <= sw_commit[1];
        O_debug_raw <= O_mode==3'd5;
    end
end

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        O_param    <= 4'd0;
        O_th_bin   <= 8'd64;
        O_th_edge  <= 8'd8;
        O_strength <= 2'd0;
        O_th_r     <= GREEN_MIN_BASE;
        O_th_d     <= TH_RG_BASE;
    end else begin

        O_param    <= sw_param;
        O_th_bin   <= 8'd64 + {sw_param, 3'b000};
        O_th_edge  <= 8'd8  + (sw_param + {sw_param, 1'b0});
        O_strength <= sw_param[1:0];
        O_th_r     <= GREEN_MIN_BASE + {sw_param, 3'b000};
        O_th_d     <= TH_RG_BASE + (sw_param + {sw_param, 1'b0});
    end
end

wire [47:0] W_bus_next = { sw_commit[0],baseline_request,audit_request, O_debug_raw, O_dilation_en,
                           O_th_d, O_th_r,
                           O_detect_en, O_osd_en, O_strength,
                           O_th_edge, O_th_bin, O_param, O_mode };

reg [47:0] pending_bus;
reg [3:0] bus_quiet;

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        O_ctrl_bus    <= 48'd0;
        pending_bus   <= 48'd0;
        bus_quiet     <= 0;
        O_ctrl_toggle <= 1'b0;
    end else begin
        if(pending_bus!=W_bus_next)begin pending_bus<=W_bus_next;bus_quiet<=0;end
        else if(bus_quiet<8)bus_quiet<=bus_quiet+1'b1;
        else if(O_ctrl_bus!=pending_bus)begin
            O_ctrl_bus<=pending_bus;O_ctrl_toggle<=~O_ctrl_toggle;
        end
    end
end

endmodule

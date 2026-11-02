// 文件名   : cdc_sync.v
// 模块功能 : 跨时钟域同步器
//   cdc_bit_sync : 单比特电平同步(打两拍)
//   cdc_bus_sync : 多比特总线同步(toggle 握手)

//   cdc_bus_sync 使用约束: 源端必须在 I_toggle 翻转后保持 I_d 稳定
//   至少 3 个目的时钟周期。本设计中所有被同步的总线均由按键/帧同步

// 单比特电平同步

module cdc_bit_sync (
    input  I_dst_clk,
    input  I_dst_rst_n,
    input  I_d,
    output reg O_q
);
    reg q1;
    always @(posedge I_dst_clk or negedge I_dst_rst_n) begin
        if(!I_dst_rst_n)
            {O_q, q1} <= 2'b00;
        else
            {O_q, q1} <= {q1, I_d};
    end
endmodule

// 多比特总线同步 (toggle 握手, 无握手回程, 适用于慢速变化的控制量)

module cdc_bus_sync #(
    parameter W = 16
)(
    input              I_dst_clk,
    input              I_dst_rst_n,
    input  [W-1:0]     I_d,
    input              I_toggle,
    output reg [W-1:0] O_q,
    output reg         O_upd
);
    reg t1, t2, t3;

    always @(posedge I_dst_clk or negedge I_dst_rst_n) begin
        if(!I_dst_rst_n) begin
            t1    <= 1'b0;
            t2    <= 1'b0;
            t3    <= 1'b0;
            O_q   <= {W{1'b0}};
            O_upd <= 1'b0;
        end else begin
            t1    <= I_toggle;
            t2    <= t1;
            t3    <= t2;
            O_upd <= t2 ^ t3;
            if(t2 ^ t3)
                O_q <= I_d;
        end
    end
endmodule

// 复位同步释放 (异步置位, 同步释放)

module cdc_rst_sync (
    input  I_clk,
    input  I_rst_n_async,
    output reg O_rst_n
);
    reg q1;
    always @(posedge I_clk or negedge I_rst_n_async) begin
        if(!I_rst_n_async)
            {O_rst_n, q1} <= 2'b00;
        else
            {O_rst_n, q1} <= {q1, 1'b1};
    end
endmodule

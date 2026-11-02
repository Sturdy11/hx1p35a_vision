create_clock -name {sys_clk_50m} -period 20.000 -waveform {0.000 10.000} [get_ports {I_sys_clk}]
create_clock -name {mipi_rx_ck_pad} -period 4.167 -waveform {0.000 2.083} [get_nets {IO_rx_clk_pad_p}]

derive_clocks

rename_clock -name {pll_clk_100m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {pll_clk_24m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {HDMI_PIXEL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[4]}]
rename_clock -name {HDMI_SERIAL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[5]}]

rename_clock -name {MIPI_RX_BYTE_CLK} [get_clocks {u_mipi_dphy_rx_ph1p_mipiio_wrapper/u_ph1p_mipiio_rx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_RX.o_fabric_div4_8_clk}]


set_clock_groups -asynchronous \
    -group [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] \
    -group [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] \
    -group [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]

#=============================================================================
# 自研模块跨时钟域时序豁免
#   auto_exposure(24MHz) -> HDMI 域 : O_mean  (cdc_bus_sync, toggle 握手)
#   alg_ctrl(100MHz)     -> HDMI 域 : 控制总线 (cdc_bus_sync, toggle 握手)
#   alg_ctrl(100MHz)     -> 摄像头域: 控制总线 (cdc_bus_sync, toggle 握手)
#   video_overlay 内部 osd/skin 无关
#   说明: 上述总线均采用 "数据 + 翻转标志" 协议, 源端数据在目标端采样前
#         已稳定 >= 3 个目标时钟, 属多周期路径, 故做时序豁免。
#=============================================================================
set_false_path -from [get_clocks {pll_clk_24m}]  -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -from [get_clocks {pll_clk_100m}] -to [get_clocks {HDMI_PIXEL_CLK}]

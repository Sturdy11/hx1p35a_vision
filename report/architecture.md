# 工程结构与数据流

当前顶层：`src/rtl/design_top_wrapper116.v`。硬件配置保持 V116。

1. SC500CS 通过 I2C 初始化，输出两路 MIPI CSI-2 RAW10。
2. D-PHY、CSI-2 解包和 RAW10 重排后进入摄像头时钟域 ISP。
3. ISP 完成去马赛克、曝光测光、白平衡、色彩/亮度处理和 RGB 打包。
4. `video_in78` 按完整帧接收，跨时钟 FIFO 后写 DDR2；四个帧槽避免覆盖正在显示或等待显示的帧。
5. `video_out77` 在显示帧边界切换到可用完整帧，DDR2 读 FIFO 向 HDMI 像素域供数。
6. `scene_detect116` 在显示域对 RGB 分割、提取候选并进行六类规则判定；`scene_stabilize110` 关联并稳定轨迹。
7. `focus114` 在消隐期串行扫描 24 个目标；目标描述符、焦点坐标、十进制字符和中心十字整包提交。
8. `display_modes111` 和 `scene_overlay116` 选择显示模式并叠加框、文字和 Logo，送往 HDMI。

关键文件：

| 文件 | 职责 |
|---|---|
| src/rtl/uics500_cfg/uics500reg_720p60.v | 传感器寄存器表；当前为 30 帧配置 |
| src/rtl/imgproc/auto_exposure81.v | 曝光和模拟增益调节 |
| src/rtl/imgproc/scene_detect116.v | 分割、候选提取、特征和六类识别 |
| src/rtl/imgproc/scene_stabilize110.v | 轨迹关联、确认和短时保持 |
| src/rtl/imgproc/focus114.v | AUTO/MAN 选择和中心坐标 |
| src/rtl/imgproc/scene_audit113.v | 候选数量、基准和缺失状态 |
| src/rtl/imgproc/scene_source113.v | 不同源帧的观察去重与质量门控 |
| src/rtl/imgproc/frame_rates108.v | CAM/HDMI/DET 每秒计数 |
| src/rtl/imgproc/video_overlay116.v | 显示域集成与原子结果包 |
| src/ip/ | 厂商生成的 PLL、FIFO、RAM 和 DDR2 依赖 |

源码中的版本数字属于模块接口标识。它们保留，以维持层次约束和已验证实例关系；仓库只引用当前使用的版本。`sim/reference` 中的旧模块仅用于回归对照，不参与综合。厂商加密模块按原形式保留，使用 TD 支持的加密 IP 流程编译。

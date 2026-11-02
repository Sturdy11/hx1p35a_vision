# HX1P35A 医疗器械视觉识别系统

基于安路 HX1P35A（PH1P35MDG324）、SC500CS、板载 DDR2 与 HDMI 的绿色铺布场景多目标识别工程。当前版本为 V116 的仓库整理版，保留剪刀、镊子、止血钳、纱布、棉球和缝针六类识别、跟踪和数量清点。

## 快速开始

1. 安装安路 Tang Dynasty 6.2.1（原构建版本为 6.2.168116）。
2. 打开 [build/project.al](build/project.al)，顶层为 `design_top_wrapper116`，器件为 `PH1P35MDG324`，速度等级 `-3`。
3. 直接观察已发布版本时，下载 [build116_compare_stable.bit](build/bitstreams/build116_compare_stable.bit)。
4. 用 Python 3.10 或更新版本检查仓库完整性：

```powershell
python build/verify.py
```

TD 命令行构建使用可配置工具路径，生成文件统一放在忽略目录 `build/out/`：

```powershell
pwsh -File build/build.ps1 -TdPath 'D:/TD_6.2.1/TD_6.2.1/APP/bin/td_commands_prompt.exe' -PrepareOnly
pwsh -File build/build.ps1 -TdPath 'D:/TD_6.2.1/TD_6.2.1/APP/bin/td_commands_prompt.exe' -ElaborateOnly
pwsh -File build/build.ps1 -TdPath 'D:/TD_6.2.1/TD_6.2.1/APP/bin/td_commands_prompt.exe'
```

上面的安装位置是调用示例，可以换成自己的位置。也可把 TD 加入 PATH，或设置 `TD_HOME` 为包含 `APP` 的安装目录。准备、展开、布局布线三种入口共用同一份参数化脚本；完整构建会检查最终 setup/hold，负裕量时停止生成下载文件。

## 当前功能和边界

| 功能 | 当前行为 |
|---|---|
| 视频 | 1280×720，摄像头约 30 FPS，HDMI 约 60 FPS |
| 六类识别 | 绿色背景分割、形状及亮度特征规则、候选合并和跨帧稳定处理 |
| 多模式 | 增强 → 灰度 → 二值化 → 分割预览 → Sobel → 原图 |
| 信息叠加 | 类别框、计数、ID、中心十字、坐标、帧率、延迟和安路 Logo |
| 动态跟踪 | AUTO 选择移动目标；MAN 按 ID 跟随；HOLD 明确表示旧坐标 |
| 数量清点 | CAND 候选 → CHECK 核对 → 再次长按确认 BASE；稳定缺失后提示 |
| 光照适应 | 曝光、增益、白平衡和局部分割阈值调节 |
| 运动提示 | 网格帧差统计与状态显示 |

本版本采用规则识别器，不包含已训练的 CNN。CAM、HDMI、DET 分别统计采集、显示和有效识别更新率。新坐标随有效识别更新，典型实板读数约 20 次/秒；HDMI 刷新率不代表每秒有 60 次独立识别。手部遮挡、重叠、强反光和极暗光仍可能影响结果。

`uics500reg_720p60` 是保留的模块名，当前 VTS=2000，输出约 30 FPS。720p60 尚未在这个发布包中启用。

## 操作

| 控制 | 操作 |
|---|---|
| KEY1（D5） | 下一个显示模式 |
| KEY2（A9） | 上一个显示模式 |
| KEY3（B9） | 开关全部信息叠加 |
| KEY4（C7）短按 | 进入 MAN，轮选目标 |
| KEY4 长按约 1 秒并松开 | 请求采集待保存数量，等待 CHECK；核对六类数量后再次长按保存 BASE |
| 逻辑 SW1（A4） | 清点使能，低有效 |
| 逻辑 SW2（B4） | 识别使能，低有效；关闭后再开启恢复 AUTO |

SW1/SW2 为源码中的逻辑称呼，请按 A4/B4 管脚核对开发板丝印或外接按键。原图模式暂停识别并清除基准；断电、复位或关闭相应使能也会清除基准。CHECK 表示候选观察一致，保存前仍需检查类别和数量。

## 目录

```text
hx1p35a_vision/
├── README.md
├── src/
│   ├── rtl/              当前工程引用的 RTL
│   └── ip/               TD 生成的 PLL、FIFO、RAM、DDR2 及加密 IP
├── sim/
│   ├── run.py            可重定位的回归入口
│   ├── cases.json        29 项测试计划
│   ├── cases/            测试台
│   └── reference/        仅用于仿真对照的旧模块
├── build/
│   ├── project.al        TD 工程
│   ├── build.ps1         构建入口
│   ├── verify.py         路径、文件、等价性与 bit 校验
│   └── bitstreams/       已发布 V116 下载文件
├── board/                引脚约束、时钟约束和操作说明
├── data/fixtures/        压缩的仿真诊断样本
└── report/               整理说明、发布来源、资源时序和验证证据
```

仓库内路径使用小写英文字母、数字、下划线、连字符及扩展名分隔符；`README.md` 沿用 GitHub 和赛题示例的惯用名称。中文仅存在于文件正文。

## 验证与资源

当前打包保留 29 项 V116 测试的输入和历史通过日志，快速复测命令如下：

```powershell
python sim/run.py
python sim/run.py --all
```

默认复测 8 项，覆盖移动坐标、包装层、显示包一致性、纱布、两种 RAM 读延迟、完整六类场景和器械形态；`--all` 运行全部 29 项，其中完整 720p 视频仿真耗时较长。需要已安装的 ModelSim，或用 `--vsim` 指定可执行文件。新输出写入 `sim/out/`。

V116 原始布局布线结果：Slice 20701/21216，LUT6 19894/21216，ERAM 77/108，DSP 24/40；setup +0.125 ns，hold +0.020 ns，STA 覆盖 94.31%。现有 I2C/DDR/IO 约束缺口仍保留，结论限于原约束范围。

这次整理核对了清理前后的 HDL 有效 token 和综合指令；随包 bit 文件保持原始 V116 哈希。上面的资源、时序是原始 V116 结果，不作为重定位后重新布局布线的结果。当前复测记录见 [report/cleanup.md](report/cleanup.md)。

## 文档

- [板卡控制与信号](board/controls.md)
- [工程结构与数据流](report/architecture.md)
- [整理与优化记录](report/cleanup.md)
- [GitHub 上传步骤](report/github_upload.md)
- [第三方来源与许可说明](report/third_party.md)

# V116 仓库整理与优化

## 结果

建立可独立复制的 `hx1p35a_vision` 目录，按 `src/sim/build/board/data/report` 分类。原始工作目录约 113 MiB，待上传内容约 7 MiB，减少约 94%。原 V116 发布目录保留，可继续使用原下载文件。

本轮完成：

- 清理 45 个自研 HDL 文件中的历史版本长注释、废弃代码块、旧排查说明和重复分隔线，净减少约 94 KB；保留版权、综合指令和有用的 CDC/FIFO 说明。
- 修正 DDR2、摄像头 30 帧配置、控制输入和 J14 清点报警等注释；补齐当前六类识别链路说明。
- 保留当前 TD 工程的 84 项引用及全部相关 IP 目录，共打包 173 个源码、IP 和约束文件；旧参考模块仅放到仿真目录。
- 把仓库内文件名和目录统一为英文小写路径，保留 `README.md` 惯用名称；同步修正工程和 IP 元数据引用。
- 构建脚本通过参数、PATH 或 TD_HOME 找到工具；构建输出固定隔离在忽略目录，消除原工程中的个人电脑绝对路径依赖。
- 消除重复的 CompileOrder 编号，保持原有排序关系；保留器件、速度等级、模块标识和布局布线策略。
- 增加依赖、文件哈希、源码有效 token、下载文件以及测试证据的检查入口；仿真工作库和临时生成文件移至工程外缓存。
- Git 禁止自动换行转换，保持厂商加密 IP 和发布清单的字节一致；普通文本 diff 仍可使用。
- 保留 29 项测试计划、诊断样本和历史通过日志；本轮重新执行 8 项代表性回归。

这次优化针对源码维护、工程可移植性和上传体积。清理前后 45 个 HDL 文件的有效 token 及综合指令一致，随包 bit 文件与原始 V116 完全一致。未启用 60 帧，也未重新布局布线；资源、时序指标来自原 V116 发布记录。

## 本轮验证

| 验证项 | 结果 | 证据 |
|---|---|---|
| 当前工程 84 项文件引用 | 完整，全部位于仓库内 | source_map.json、build/verify.py |
| 注释清理前后逻辑 | 45 项 token 核对一致 | source_map.json 中的逻辑哈希 |
| 原始 V116 发布包 | 核验通过，原目录源码及 bit 未变 | v116_baseline.json 中的发布清单哈希 |
| TD 6.2.168116 顶层展开 | 通过，推导 41 个 RAM | elaboration.log |
| 移动目标与实时坐标 | 通过 | current_sim/focus116.log |
| 六模式/基准门控、显示包 | 通过 | current_sim/wrapper116.log、packet116.log |
| 纱布去重 | 通过 | current_sim/gauze116.log |
| 棉球与两种 RAM 读延迟 | 通过 | current_sim/white_stream116_l1.log、white_stream116_l2.log |
| 完整六类场景 | 通过 | current_sim/fullscene116.log |
| 剪刀/止血钳方向与钳口案例 | 通过 | current_sim/jaws116.log |
| 独立目录复制与检查 | 通过 | relocation.json |
| 独立目录 TD 展开与焦点仿真 | 通过 | relocation_elaboration.log、relocation_focus.log |
| Git 存储与重新检出 | 在 core.autocrlf=true 下仍通过全部文件哈希核对 | github_checks.json |

顶层展开保留原 I2C/匿名实例等警告，没有新增替换初始化逻辑的改动。历史 29 项日志与本轮 8 项复测分别保存，完整 720p 长视频测试未在本轮重复执行。

## 可复现的证据链

| 证据 | 观察与结论 | 后续操作 |
|---|---|---|
| E-01：source_map.json 与 package_manifest.json | 精简文件均可追溯；清理过的 HDL 保持有效代码一致 | `python build/verify.py` |
| E-02：validation.json、current_sim/ | 8 项复测覆盖识别、跟踪及显示包契约 | `python sim/run.py` |
| E-03：elaboration.log、relocation.json | 新目录结构在本机和另一独立路径均可展开 | `pwsh -File build/build.ps1 -ElaborateOnly`，通过参数指定 TD |
| E-04：v116_baseline.json | 下载文件保留原版哈希，原时序记录与新源码整理记录区分 | 核验后下载 `build/bitstreams/build116_compare_stable.bit` |

## 文件清单维护

校验脚本会检查已记录的文件哈希。修改文档或脚本后，在确认对应验证已完成的前提下运行 `python build/refresh_manifest.py` 更新文件清单，再运行 `python build/verify.py`。

修改硬件逻辑时应建立新版本并重新仿真、综合、布局布线、验证时序和发布来源；当前 source_map 中的 V116 等价性记录不应作为新逻辑的验证结果。

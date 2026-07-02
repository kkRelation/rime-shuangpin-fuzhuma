# 通用层优化进度

本文记录当前已经完成的高优先级优化，以及剩余待办项，便于后续继续沿着 Rime 通用层演进。

相关背景见：[architecture-notes.md](D:/C2D/Desktop/Code/Lua/inputMethod/rime-moqi-wanxiang-schemas/md/architecture-notes.md)。

## 已完成

### jianma_show 热路径优化

文件：

- [lua/moqi/jianma_show.lua](D:/C2D/Desktop/Code/Lua/inputMethod/rime-moqi-wanxiang-schemas/lua/moqi/jianma_show.lua)

已完成内容：

- 默认关闭热路径 `log.info`。
- 增加 `jianma_show/debug: true` 调试开关。
- 改为按候选被 Rime 实际迭代到时才处理，翻页时自然增量执行。
- 增加 `input` 级缓存：当前输入不变时，同词不重复反查。
- 当前输入变化时清空本次提示缓存。
- 保持候选全量透传，不过滤、不改排序、不影响上屏。
- 单字候选不提示多字简码。
- 对 2-4 字词保留静态输入长度门槛：当前输入码长 `< 4` 不查。
- 增加动态提示门槛：只有存在严格短于当前输入的编码时才提示。

已避免的误判：

- `B超 = bic` 这类主码本来就较短的词，不再误判为“存在更短简码”。
- `custom_phrase_super_4jian_no_conflict` 中 `4` 码词不再被误提示，因为它们并不比当前全码更短。

### Shift 候选上屏后切英

文件：

- [lua/sbxlm/shift_commit_candidate.lua](D:/C2D/Desktop/Code/Lua/inputMethod/rime-moqi-wanxiang-schemas/lua/sbxlm/shift_commit_candidate.lua)
- [moqi.yaml](D:/C2D/Desktop/Code/Lua/inputMethod/rime-moqi-wanxiang-schemas/moqi.yaml)

已完成内容：

- 中文 composing 状态下按 `Shift` 时，先提交当前候选，再切换到英文。
- 非目标场景继续交给原有 `ascii_composer` 处理。
- 保持其他输入行为不变。

### 文档与方向判断

文件：

- [md/architecture-notes.md](D:/C2D/Desktop/Code/Lua/inputMethod/rime-moqi-wanxiang-schemas/md/architecture-notes.md)

已完成内容：

- 明确长期地基为 `rime/weasel + librime`。
- 明确借鉴方向：
  `WindInput` 主要借鉴前端分层与产品形态。
  `cxx-ime` 主要借鉴热路径性能工程。
- 明确优先顺序：
  先做 Rime 通用层优化，再视瓶颈迁移到 `librime` 插件。

## 待办

### 高优先级

#### pro_comment_format

文件：

- [lua/pro_comment_format.lua](D:/C2D/Desktop/Code/Lua/inputMethod/rime-moqi-wanxiang-schemas/lua/pro_comment_format.lua)

现状问题：

- `C.func()` 每次调用都会执行 `C.init(env)` 和 `CR.init(env)`。
- `CR.init` 中会重建整张 `CR.corrections` 表。
- 注释解析和辅助码提取仍有明显热路径开销。

建议优化：

- 配置只在 `init(env)` 读取一次。
- `CR.corrections` 改为模块级常量。
- `fuzhu_type -> pattern` 改为模块级常量。
- 仅在需要时解析 `comment`。
- 按候选数量增加处理预算，避免无条件扫描全部候选。

#### aux_lookup_filter

文件：

- [lua/aux_lookup_filter.lua](D:/C2D/Desktop/Code/Lua/inputMethod/rime-moqi-wanxiang-schemas/lua/aux_lookup_filter.lua)

现状问题：

- 触发辅助码筛选后，会收集候选再做变体组分析。
- 对大候选流场景仍可能过重。

建议优化：

- 给候选收集增加上限。
- 找到足够匹配后提前停止。
- 保持当前辅助码表懒加载设计。

#### stick

文件：

- [lua/stick.lua](D:/C2D/Desktop/Code/Lua/inputMethod/rime-moqi-wanxiang-schemas/lua/stick.lua)

现状问题：

- 收益不如前两项大，但逻辑仍有整理空间。
- 仍可进一步压缩非目标场景下的处理开销。

建议优化：

- 严格限定处理范围在短输入场景。
- 检查首候选路径，避免潜在重复输出风险。
- 让透传路径更轻。

### 中优先级

#### 基准与回归样本

建议新增：

- 固定输入样本集。
- 首屏候选预期结果。
- 热路径行为变更前后的手工或脚本化对照。

目的：

- 避免只凭体感做优化。
- 为后续迁移到 `librime` 插件提供基线。

#### 静态规则预生成

建议方向：

- 能在词典构建期生成的规则，尽量不要在 Lua 热路径实时计算。
- 将静态码表、固顶词、提示映射更多地下沉到词典或构建脚本。

## 何时考虑 librime 插件

以下情况再考虑把 Lua 逻辑迁到 `librime` C++ 插件：

- Lua 版本已完成缓存、懒处理、预算控制后，仍然明显处于热路径瓶颈。
- 某模块需要更稳定的低延迟表现。
- 某模块的数据结构明显更适合 C++ 常驻索引。

当前最可能后续插件化的点：

- `pro_comment_format`
- 更复杂的候选注释/提示逻辑
- 短码首屏缓存或固顶索引

## 何时考虑借鉴 WindInput

当前阶段不建议先动前端。

WindInput 的借鉴点应放在后续阶段：

- Windows 前端分层
- 设置工具
- 候选 UI 与产品交互
- 进程边界与服务组织

这些不属于当前这一轮 Rime 通用层性能优化的主线。

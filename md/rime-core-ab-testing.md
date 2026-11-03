# Rime Core A/B Testing

目标：用可重复的 A/B 测试定位普通输入路径中的 Rime Core 瓶颈，区分 translator 重复查询、动态组句、speller 分支和词库规模的成本。在完成这些测试前，不以 fork Weasel 作为主要优化方向。

## Current Conclusions

- Lua 普通过滤链通常约为 0-1 ms，不是当前主瓶颈。
- 关闭 octagram 后，普通输入的 Core 延迟明显下降，因此保持 `grammar: {}` 和 `translator/contextual_suggestions: false` 作为后续测试基线。
- 仍存在大量 Core 慢事件，说明主 `script_translator`、speller/prism、词典查询、动态组句或 translator 合并仍需拆分测试。
- `add_user_dict` 有 `ac` tag，预计只在自造词路径工作；普通输入测试中应保留。
- `user_dict_set` 没有独立 tag，并绑定完整的 `moqi_wan.extended`。即使 `user.custom.dict` 很小，它也可能在普通路径重复执行完整 ScriptTranslator 查询。

## Measurement Caveat

当前配置 `moqi_latency_probe/threshold_ms: 50` 会记录全部慢事件，并额外周期采样。由此得到的平均值偏向慢样本，不能视为全部按键的真实平均延迟。

2026-07-12 修复了探针原先跨 engine/context 共用模块全局计时状态的问题。带有 `session=` 的 `no-octagram-a0-isolated` 及后续日志才可用于正式 A/B；分析器把此前数据标记为 `legacy-global`，只保留作历史参考。

使用日志时分清两个目的：

- 慢事件定位：保留 `threshold_ms: 50`，观察慢输入、输入长度和最大值。
- Profile A/B 比较：所有轮次必须使用完全相同的 `threshold_ms`、`log_every`、输入方式和测试时长。重点比较 Core 慢事件数量、P95 和最大值，不单独依据 Avg 下结论。

后续可改进分析器，加入每个 profile 的总按键数和慢事件比例；在此之前，每轮至少运行两次，只有方向一致才认为结果可信。

## Test Order

每轮只改变一个算法变量。所有轮次均以当前 `no-octagram` 配置为基线。

### A0: No Octagram Baseline

目的：建立相同机器状态下的新基准，不直接复用历史日志。

配置：

```yaml
moqi_latency_probe/profile: no-octagram-a0-isolated
grammar: {}
translator/contextual_suggestions: false
```

预期功能影响：无新增影响；语言模型已经关闭。

### A1: Remove Only user_dict_set

目的：判断第二个普通路径 ScriptTranslator 是否重复构建音节图和查询完整系统词典。

变更：

- 从 `engine/translators` 移除 `script_translator@user_dict_set`。
- 保留主 `script_translator`。
- 保留 `script_translator@add_user_dict`，避免把 `ac` 自造词路径混入变量。
- profile 使用 `no-octagram-no-user-dict-set`。

预期功能影响：测试期间不显示 `user.custom.dict` 中由 `user_dict_set` 提供的候选；`ac` 自造词入口仍保留。

判定：

- 改善明显：长期方案应把用户词典查询合并进主 `script_translator`，避免第二次系统词典查询，而不是永久放弃用户词典。
- 改善很小：恢复 `user_dict_set`，继续 A2。

### A2: Disable Dynamic Sentence Generation

目的：隔离 ScriptTranslator 在没有可靠完整词命中时构建 WordGraph 和动态组句的成本。

变更：

```yaml
translator/enable_sentence: false
moqi_latency_probe/profile: no-octagram-no-sentence
```

其余 translator 和词典恢复为 A0 状态。

预期功能影响：已有字、词和词库中的长词仍可出现；临时组合出来但词库中不存在的整句候选会消失。这是诊断 profile，不是默认配置提案。

判定：

- 改善明显：瓶颈主要在动态组句。后续考虑按输入长度、模式或命中情况限制组句，而不是完全关闭。
- 改善很小：恢复动态组句，继续 A3。

### A3: Reduce Speller/Auxiliary-Code Branching

目的：判断墨奇辅助码的多条 `derive`、`abbrev` 规则是否使 prism/syllable graph 分支过多。

变更：临时移除本方案追加的辅助码 algebra：

```yaml
# speller/algebra/+:
#   __include: aux_patch
moqi_latency_probe/profile: no-octagram-simple-speller
```

保留 `flypy_speller`，其余配置恢复为 A0 状态。

预期功能影响：纯双拼仍可测试；墨奇辅助码、一位辅助码、二位辅助码及部分整句辅助码能力会临时失效。只用于定位算法分支成本。

判定：

- 改善明显：优化重点转向减少等价派生路径、按输入状态拆分 prism，或将部分辅助码筛选从全局 algebra 移到显式触发路径。
- 改善很小：恢复完整 algebra，继续 A4。

### A4: Lean Dictionary

目的：隔离扩展词库和细胞词库带来的查询、同音候选和组句图规模成本。

变更：创建临时诊断词典，只导入以下基础表，并让普通路径上的 ScriptTranslator 都指向它：

```yaml
import_tables:
  - cn_dicts/8105
  - cn_dicts/base
  - cn_dicts/ext
```

profile 使用 `no-octagram-lean-dictionary`。不要直接删除或修改现有词库文件。

预期功能影响：大量专业词、细胞词库词条、大字集字词会临时消失。

判定：

- 改善明显：把词库划分为常用层和扩展层，重新评估细胞词库默认加载策略及词频质量。
- 改善很小：主因更可能是 syllable graph/translator 调度，而不是词库规模本身。

## Run Procedure

每个 profile 按相同步骤执行：

1. 确认只启用当前 profile，并保持 octagram 关闭。
2. 将 `moqi_latency_probe/profile` 改为唯一名称，避免与旧日志混合。
3. 重新部署 Rime，确认部署成功。
4. 先输入约一分钟，让词典文件和相关页面进入系统缓存；预热数据不参与主观结论。
5. 在相同应用、相同电源模式和相近 CPU 状态下正常输入至少 5-10 分钟。
6. 输入样本应覆盖一至四码、连续长句、退格修改和候选翻页；不要使用反查前缀或反引号辅助筛选来评价普通路径。
7. 运行分析器：

```powershell
pwsh -NoProfile -File "tools/rime-ab/analyze-rime-latency.ps1"
```

8. 记录 Core P50/P95/P99/Max、慢事件数量、Lua P95 和主观卡顿感。
9. 同一 profile 至少重复一次；两次结果方向一致后再进入下一轮。

## Result Table

| Profile | Run | Duration | Core P50 | Core P95 | Core P99 | Core Max | Slow events | Lua P95 | Notes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `no-octagram-a0-isolated` | 1 | ~55 min | 66 | 103 | 122 | 150 | 639 | 1 | 645 ordinary late rows; threshold-biased; backtick excluded |
| `no-octagram-a0-isolated` | 2 | | | | | | | | |
| `no-octagram-no-user-dict-set` | 1 | ~25 min | 73 | 114 | 133 | 139 | 337 | 1 | 338 ordinary late rows; no improvement; backtick excluded |
| `no-octagram-no-user-dict-set` | 2 | skipped | | | | | | | A1 rejected after run 1; user dictionary restored |
| `no-octagram-no-sentence` | 1 | ~93 min | 10 | 13 | 13 | 13 | 0 | 1 | No slow event; dynamic sentence functionality degraded |
| `no-octagram-no-sentence` | 2 | extended | 12 | 1618 | 1618 | 1618 | 4 | 1 | Routine 6-15 ms; rare 142/164/972/1618 ms Core spikes |
| `no-octagram-simple-speller` | 1 | invalid | | | | | | | Removed required pure-double-pinyin mapping; sentence and short-word input broke |
| `no-octagram-simple-speller` | 2 | | | | | | | | |
| `no-octagram-lean-dictionary` | 1 | | | | | | | | |
| `no-octagram-lean-dictionary` | 2 | | | | | | | | |

## Decision Threshold

优先关注能重复出现的相对变化：

- Core P95 或慢事件数量下降约 15% 以上：值得继续设计保留功能的正式优化。
- 变化小于约 5%：通常视为噪声或低优先级。
- 变化在 5%-15%：延长测试，并在相同机器状态下再跑一轮。
- Lua P95 仍在约 0-1 ms：继续把普通路径重点放在 Rime Core，不回到 Lua filter 微调。

这些阈值是工程筛选标准，不是统计显著性证明。CPU 频率、电源模式、前台应用和日志写入都可能影响结果。

## After A/B

如果 A1-A4 都不能解释主要延迟，再考虑给 librime 加 C++ 级分段计时，分别测量：

```text
BuildSyllableGraph
Dictionary::Lookup
UserDictionary::Lookup
PrepareForMakingSentence
Poet::MakeSentence
Translation merge
```

这属于 librime Core 插桩或 fork 的范围。Weasel fork 主要用于验证 TSF、候选窗口和渲染延迟，不应替代上述 Core A/B。

## Tooling Status

`tools/rime-ab/apply-rime-ab.ps1` 当前仍支持早期 profiles，但尚未精确实现本文的 A1-A4。特别是旧的 `no-user-translators` 会同时移除 `user_dict_set` 和 `add_user_dict`，不适合作为 A1 的最终数据。

开始每轮实验前，应先为对应 profile 补齐脚本/patch，并检查部署后的 build 配置确实生效。当前方案曾出现 `.custom.yaml` 被 schema 内直接 patch 覆盖的情况，因此不能只依据源文件推断实验已启用。

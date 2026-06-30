# 输入法架构长期维护判断

本文记录对 WindInput、rime/weasel + librime、cxx-ime 三类架构的比较，以及本项目后续演进时可借鉴的方向。

## 结论

长期维护的最优地基应继续选择 **rime/weasel + librime**：

- **librime** 作为输入引擎和方案生态核心。
- **Weasel** 作为 Windows 现阶段前端。
- 吸收 **WindInput** 的前端薄化、服务分层、现代设置工具思想。
- 吸收 **cxx-ime** 的热路径性能工程、短输入快速路径、查询预算和索引化思想。

更具体地说，最优路线不是三选一，而是：

> Rime/librime 做内核地基，WindInput 做外壳架构参考，cxx-ime 做性能工程参考。

这样迁移成本最低，同时能够最大程度吸收另外两者的优势。

## 三者定位

### rime/weasel + librime

优势：

- 已有成熟的 Rime schema DSL、spelling algebra、OpenCC、Lua、插件体系。
- 已经有庞大的方案生态和用户配置生态。
- librime 是跨平台 C++ 输入引擎，天然适合作为可维护内核。
- Weasel 是 Windows 官方前端，已经处理了大量 TSF、UI、IPC、部署细节。
- 当前项目本身就是 Rime 配置与 Lua 行为层，继续基于它演进成本最低。

劣势：

- Weasel 的产品体验、设置工具、UI 架构不够现代。
- 某些性能优化如果只靠 Lua，会碰到热路径开销。
- 前端和配置体验的现代化，需要额外工程投入。

判断：

- 这是当前项目最稳的长期地基。
- 优先通过 schema、Lua、librime plugin 演进。
- 不应轻易改 librime core，也不应轻易重写 Weasel。

### WindInput

优势：

- 架构上更现代产品化：平台前端薄，输入服务、候选管理、UI、设置工具分层更清晰。
- Windows 侧以 TSF 前端捕获键盘，后端集中处理输入逻辑。
- 设置工具和配置体验更接近现代应用。
- 值得借鉴前端薄化、服务边界、设置工具和 UI 组织方式。

劣势：

- 如果直接以 WindInput 为地基，会丢掉 Rime 的方案生态。
- 需要重新承接词典、码表、用户词、OpenCC、Lua 扩展、方案兼容等长期成本。
- 对本项目来说，迁移成本远高于收益。

判断：

- 不适合作为本项目当前地基。
- 适合作为未来 Windows 前端、设置工具、进程边界的参考。

### cxx-ime

优势：

- 性能工程思路非常明确。
- 适合借鉴短输入快速路径、mmap/预构建索引、Top-K 收集、查询预算、用户词多索引。
- 对热路径、延迟、缓存命中、P50/P99 等指标有更强工程意识。

劣势：

- 更像一个专用高性能输入引擎，而不是 Rime 这种通用方案生态。
- 直接迁移会失去 Rime schema、Lua、OpenCC、现有词库和用户配置能力。
- 替换 librime 的成本过高。

判断：

- 不适合作为本项目地基。
- 非常适合作为性能优化方法论来源。

## 可吸收的设计原则

### 从 WindInput 借鉴

- 前端尽量薄，只处理平台输入事件、候选窗口、状态展示。
- 输入逻辑集中在引擎层，避免散落在 UI 或前端平台代码里。
- 设置工具独立现代化，减少用户直接编辑 YAML 的成本。
- 配置、状态、用户词、候选 UI 保持清晰边界。

在本项目中的落地方式：

- 短中期仍使用 Weasel，不重写前端。
- 将行为逻辑尽量放在 schema、Lua processor/filter/translator、librime plugin 中。
- 将复杂功能拆成独立模块，并通过 schema 开关启用。
- 未来如果重做 Windows 前端，应保留 librime 作为核心。

### 从 cxx-ime 借鉴

- 把 1-6 位短输入视为最高频热路径。
- 对短码、首屏候选、高频词、用户常选词做缓存。
- 候选处理使用 Top-K 或流式处理，避免全量收集再排序。
- 为复杂 filter/translator 设置处理预算，例如最多扫描 N 个候选。
- 静态可推导规则尽量在构建期预生成，避免运行期重复计算。
- 用户词、固顶词、自定义短语应建立索引，不应线性扫描。
- 建立 benchmark 和回归样本，避免只凭体感优化。

在本项目中的落地方式：

- Lua `init(env)` 中预加载配置和索引。
- Lua `func()` 与 filter 迭代中避免读文件、解析 YAML、构造大表。
- filter 尽量只处理前几十个候选，或只对特定 tag/码长启用。
- 对性能敏感的 Lua 模块，迁移到 librime C++ plugin。
- 为常用输入样本建立固定测试集，记录首屏候选和耗时变化。

## 推荐演进路线

### 短期

- 审计当前 Lua processors/filters/translators 的热路径。
- 给候选处理逻辑增加上限，避免无条件扫描全部候选。
- 将静态规则预生成到词典或 schema，减少实时计算。
- 为新增行为增加 schema 开关，例如：

```yaml
shift_commit_candidate:
  enabled: true
```

- 建立小型 benchmark 文档或脚本，固定输入样本和预期候选。

### 中期

- 将首屏短码缓存、固顶候选、用户词索引等性能敏感逻辑模块化。
- 对高频 Lua 模块做 profiling，确认瓶颈后迁移到 C++ librime plugin。
- 避免修改 librime core，优先通过 plugin 注册 processor/filter/translator。
- 将项目内复杂 Lua 逻辑整理成清晰模块边界。

### 长期

- 若 Weasel 前端体验成为主要瓶颈，再考虑 WindInput 风格的新 Windows 前端。
- 新前端仍应保留 librime 作为输入核心。
- 前端只负责 TSF、候选窗口、设置界面、进程边界。
- 输入语义、方案规则、词典、用户词、候选处理仍由 librime/schema/plugin 承担。

## 决策原则

- 能用 schema 表达的，不写 Lua。
- 能预生成的，不在运行期计算。
- 能用 Lua 清晰实现且不在热路径上的，不写 C++。
- Lua 成为热路径瓶颈后，再迁到 librime plugin。
- 不为了单点性能重写成熟生态。
- 不在当前项目中承担 TSF 前端重写成本。

## 参考项目

- WindInput: <https://github.com/huanfeng/WindInput>
- librime: <https://github.com/rime/librime>
- Weasel: <https://github.com/rime/weasel>
- cxx-ime: <https://github.com/deanxyuan/cxx-ime>

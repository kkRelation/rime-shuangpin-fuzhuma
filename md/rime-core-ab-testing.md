# Rime Core A/B Testing

目标：用 `moqi_latency` 的 `core_ms` 判断 Rime 核心候选生成瓶颈，而不是继续猜 Lua filter。

## Profiles

- `baseline`: 当前完整配置。
- `no-octagram`: 关闭 `grammar` 和 `translator/contextual_suggestions`，验证语言模型/组词惩罚路径成本。
- `no-user-translators`: 移除 `script_translator@user_dict_set` 和 `script_translator@add_user_dict`，验证用户词典、自造词相关 translator 成本。
- `no-super-jian`: 移除 `custom_phrase_super_*jian*` table translators，验证大简码 stabledb translator 成本。
- `core-minimal`: 同时关闭 octagram、用户词典 translators、super 简码 translators，用来估算核心主 translator 的下限。

## How To Run

每轮只测一个 profile：

```powershell
pwsh tools/rime-ab/apply-rime-ab.ps1 -Profile no-octagram
```

然后重新部署 Rime，正常输入几分钟，最后统计：

```powershell
pwsh tools/rime-ab/analyze-rime-latency.ps1
```

恢复 baseline：

```powershell
pwsh tools/rime-ab/apply-rime-ab.ps1 -Profile baseline
```

## Decision Rule

看 `Late split by profile`：

- `CoreAvg/CoreP95` 明显下降：被关闭的配置就是高优先级优化对象。
- `LuaAvg/LuaP95` 基本保持 0-1ms：说明 Lua filter 仍不是主瓶颈。
- `core-minimal` 仍接近 baseline：主要成本在主 `script_translator` + `moqi_wan.extended` 大词库本身。

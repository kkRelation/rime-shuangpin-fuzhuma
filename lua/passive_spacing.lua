-- 按 8 分词上屏：等价于空格选中后补一个空格，普通空格保持连写。

local M = {}
local rime = require "sbxlm.lib"

local function current_segment(context)
  if not context or not context.composition or context.composition:empty() then
    return nil
  end
  return context.composition:back()
end

local function is_plain_key(key_event)
  return not key_event:release()
      and not key_event:ctrl()
      and not key_event:alt()
      and not key_event:super()
      and not key_event:shift()
end

local function is_punct_segment(segment)
  return segment and segment:has_tag("punct")
end

function M.init(env)
  env.passive_spacing_pending = false
  env.passive_spacing_committing_space = false
  env.passive_spacing_notifier = env.engine.context.commit_notifier:connect(function(ctx)
    if env.passive_spacing_committing_space then
      return
    end
    if not env.passive_spacing_pending then
      return
    end
    env.passive_spacing_pending = false
    local text = ctx:get_commit_text() or ""
    if text == "" or text:match("%s$") then
      return
    end
    env.passive_spacing_committing_space = true
    env.engine:commit_text(" ")
    env.passive_spacing_committing_space = false
  end)
end

function M.fini(env)
  if env.passive_spacing_notifier then
    env.passive_spacing_notifier:disconnect()
  end
end

function M.func(key_event, env)
  local context = env.engine.context
  local repr = key_event:repr()

  if not (env.passive_spacing_pending and repr == "space") then
    env.passive_spacing_pending = false
  end

  if context:get_option("ascii_mode") then
    return rime.process_results.kNoop
  end
  if not is_plain_key(key_event) then
    return rime.process_results.kNoop
  end
  if not context:is_composing() then
    return rime.process_results.kNoop
  end

  local input = context.input or ""
  if input == "" then
    return rime.process_results.kNoop
  end

  local segment = current_segment(context)
  if repr ~= "8" or is_punct_segment(segment) or not context:has_menu() then
    return rime.process_results.kNoop
  end

  env.passive_spacing_pending = true
  env.engine:process_key(rime.KeyEvent("space"))
  return rime.process_results.kAccepted
end

return M

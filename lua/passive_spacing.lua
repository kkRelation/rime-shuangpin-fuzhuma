-- 被动分词：开启 passive_spacing 后，上屏时自动补空格；按 8 可临时分词上屏。

local M = {}
local rime = require "sbxlm.lib"

local XK_Tab = 0xff09

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

local function is_short_tab_equivalent(key_event, input, segment)
  if not segment or not segment:has_tag("abc") then
    return false
  end
  if not input:match("^[a-z][a-z]?[a-z]?$") then
    return false
  end
  return key_event.keycode == XK_Tab
      or key_event.keycode == string.byte("/")
      or key_event.keycode == string.byte(".")
end

local function is_selection_key(key_event, context, input, segment)
  if is_punct_segment(segment) then
    return false
  end

  local repr = key_event:repr()
  if repr == "space" then
    return context:has_menu()
  end
  if repr == "semicolon" then
    return context:has_menu()
  end
  if repr == "1" or repr == "2" or repr == "3" then
    return context:has_menu()
  end
  return is_short_tab_equivalent(key_event, input, segment)
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
  if repr == "8" and not is_punct_segment(segment) and context:has_menu() then
    env.passive_spacing_pending = true
    env.engine:process_key(rime.KeyEvent("space"))
    return rime.process_results.kAccepted
  end

  if context:get_option("passive_spacing") and is_selection_key(key_event, context, input, segment) then
    env.passive_spacing_pending = true
  end

  return rime.process_results.kNoop
end

return M

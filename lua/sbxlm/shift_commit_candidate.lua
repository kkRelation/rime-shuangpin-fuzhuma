-- Shift 上屏候选并切换到英文。

local rime = require "sbxlm.lib"

local XK_Shift_L = 0xffe1
local XK_Shift_R = 0xffe2

local function is_shift_key(key_event)
  return key_event.keycode == XK_Shift_L or key_event.keycode == XK_Shift_R
end

local function has_extra_modifier(key_event)
  return key_event:ctrl() or key_event:alt() or key_event:super()
end

---@param key_event KeyEvent
---@param env Env
local function process(key_event, env)
  if key_event:release() or has_extra_modifier(key_event) or not is_shift_key(key_event) then
    return rime.process_results.kNoop
  end

  local context = env.engine.context
  if context:get_option("ascii_mode") or not context:is_composing() then
    return rime.process_results.kNoop
  end

  context:confirm_current_selection()
  context:commit()
  context:set_option("ascii_mode", true)
  return rime.process_results.kAccepted
end

return process

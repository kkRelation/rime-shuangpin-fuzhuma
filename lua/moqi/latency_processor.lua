local rime = require("sbxlm.lib")
local state = require("moqi.latency_state")
local M = {}

local function profile_name(env)
   return env.engine.schema.config:get_string("moqi_latency_probe/profile") or "baseline"
end

local function log_commit(env, ctx)
   if not state.key_at then
      return
   end

   local elapsed_ms = (os.clock() - state.key_at) * 1000
   if not state.should_log(env, elapsed_ms) then
      return
   end

   log.warning(string.format(
      "moqi_latency: profile=%s phase=commit seq=%d ms=%.3f input_before=%s input_now=%s keycode=%d text_len=%d",
      profile_name(env),
      state.key_seq or 0,
      elapsed_ms,
      state.key_input or "",
      ctx.input or "",
      state.keycode or 0,
      #(ctx:get_commit_text() or "")
   ))
end

function M.init(env)
   env.moqi_latency_commit_notifier = env.engine.context.commit_notifier:connect(function(ctx)
      if state.enabled(env) then
         log_commit(env, ctx)
      end
   end)
end

function M.fini(env)
   if env.moqi_latency_commit_notifier then
      env.moqi_latency_commit_notifier:disconnect()
      env.moqi_latency_commit_notifier = nil
   end
end

function M.func(key_event, env)
   if not state.enabled(env) then
      return rime.process_results.kNoop
   end

   if key_event:release() then
      return rime.process_results.kNoop
   end

   state.key_at = os.clock()
   state.key_input = env.engine.context.input or ""
   state.keycode = key_event.keycode or 0
   state.key_seq = (state.key_seq or 0) + 1
   state.candidate_logged_for_key = {}
   state.candidate_elapsed_ms = {}
   return rime.process_results.kNoop
end

return M

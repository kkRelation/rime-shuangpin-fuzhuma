local rime = require("sbxlm.lib")
local state = require("moqi.latency_state")
local M = {}

local function profile_name(env)
   return env.engine.schema.config:get_string("moqi_latency_probe/profile") or "baseline"
end

local function log_commit(env, ctx)
   local session = env.moqi_latency_state
   if not session or not session.key_at then
      return
   end

   local elapsed_ms = (os.clock() - session.key_at) * 1000
   if not state.should_log(env, session, elapsed_ms) then
      return
   end

   log.warning(string.format(
      "moqi_latency: profile=%s phase=commit seq=%d ms=%.3f input_before=%s input_now=%s keycode=%d text_len=%d session=%s",
      profile_name(env),
      session.key_seq or 0,
      elapsed_ms,
      session.key_input or "",
      ctx.input or "",
      session.keycode or 0,
      #(ctx:get_commit_text() or ""),
      session.id
   ))
end

function M.init(env)
   env.moqi_latency_state = state.attach(env)
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
   state.detach(env)
   env.moqi_latency_state = nil
end

function M.func(key_event, env)
   if not state.enabled(env) then
      return rime.process_results.kNoop
   end

   if key_event:release() then
      return rime.process_results.kNoop
   end

   local session = env.moqi_latency_state or state.attach(env)
   env.moqi_latency_state = session
   session.key_at = os.clock()
   session.key_input = env.engine.context.input or ""
   session.keycode = key_event.keycode or 0
   session.key_seq = (session.key_seq or 0) + 1
   session.candidate_logged_for_key = {}
   session.candidate_elapsed_ms = {}
   return rime.process_results.kNoop
end

return M

local state = require("moqi.latency_state")
local M = {}

local function log_candidates(env, candidates_seen)
   if not state.key_at or state.candidate_logged_for_key then
      return
   end

   local elapsed_ms = (os.clock() - state.key_at) * 1000
   state.candidate_logged_for_key = true
   if not state.should_log(env, elapsed_ms) then
      return
   end

   log.warning(string.format(
      "moqi_latency: phase=candidates ms=%.3f input_before=%s input_now=%s keycode=%d candidates_seen=%d",
      elapsed_ms,
      state.key_input or "",
      env.engine.context.input or "",
      state.keycode or 0,
      candidates_seen
   ))
end

function M.init(env)
end

function M.func(input, env)
   if not state.enabled(env) then
      for cand in input:iter() do
         yield(cand)
      end
      return
   end

   local candidates_seen = 0
   for cand in input:iter() do
      candidates_seen = candidates_seen + 1
      log_candidates(env, candidates_seen)
      yield(cand)
   end
end

return M

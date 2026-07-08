local state = require("moqi.latency_state")
local M = {}

local function log_candidates(env, phase, candidates_seen)
   if not state.key_at or state.candidate_logged_for_key[phase] then
      return
   end

   local elapsed_ms = (os.clock() - state.key_at) * 1000
   state.candidate_logged_for_key[phase] = true
   state.candidate_elapsed_ms[phase] = elapsed_ms
   if not state.should_log(env, elapsed_ms) then
      return
   end

   local early_ms = state.candidate_elapsed_ms.candidates_early or elapsed_ms
   local lua_ms = 0
   if phase == "candidates_late" and state.candidate_elapsed_ms.candidates_early then
      lua_ms = elapsed_ms - state.candidate_elapsed_ms.candidates_early
   end

   log.warning(string.format(
      "moqi_latency: phase=%s seq=%d ms=%.3f core_ms=%.3f lua_ms=%.3f input_before=%s input_now=%s keycode=%d candidates_seen=%d",
      phase,
      state.key_seq or 0,
      elapsed_ms,
      early_ms,
      lua_ms,
      state.key_input or "",
      env.engine.context.input or "",
      state.keycode or 0,
      candidates_seen
   ))
end

function M.init(env)
   local namespace = env.name_space or ""
   if namespace:match("early$") then
      env.moqi_latency_phase = "candidates_early"
   else
      env.moqi_latency_phase = "candidates_late"
   end
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
      log_candidates(env, env.moqi_latency_phase or "candidates_late", candidates_seen)
      yield(cand)
   end
end

return M

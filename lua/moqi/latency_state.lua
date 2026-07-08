local M = {
   key_at = nil,
   key_input = "",
   keycode = 0,
   candidate_logged_for_key = false,
   calls = 0,
}

function M.enabled(env)
   return env.engine.schema.config:get_bool("moqi_latency_probe/enabled") or false
end

function M.threshold_ms(env)
   local threshold = env.engine.schema.config:get_int("moqi_latency_probe/threshold_ms")
   return threshold or 10
end

function M.log_every(env)
   local log_every = env.engine.schema.config:get_int("moqi_latency_probe/log_every")
   return log_every or 50
end

function M.should_log(env, elapsed_ms)
   M.calls = M.calls + 1
   local log_every = M.log_every(env)
   return elapsed_ms >= M.threshold_ms(env) or (log_every > 0 and M.calls % log_every == 0)
end

return M

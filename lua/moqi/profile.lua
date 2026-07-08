local M = {}

local function get_int(config, key, default)
   local value = config:get_int(key)
   if value == nil then
      return default
   end
   return value
end

function M.init(env, name)
   local config = env.engine.schema.config
   env.moqi_profile_name = name
   env.moqi_profile_enabled = config:get_bool("moqi_profile/enabled") or false
   env.moqi_profile_log_every = get_int(config, "moqi_profile/log_every", 200)
   env.moqi_profile_slow_ms = get_int(config, "moqi_profile/slow_ms", 0)
   env.moqi_profile_stats = {
      calls = 0,
      candidates = 0,
      work_ms = 0,
      max_ms = 0,
      previous_work_ms = 0,
   }
end

function M.enabled(env)
   return env.moqi_profile_enabled == true
end

function M.now(env)
   if not M.enabled(env) then
      return nil
   end
   return os.clock()
end

function M.add_work(env, started_at)
   if not started_at then
      return
   end
   local elapsed_ms = (os.clock() - started_at) * 1000
   local stats = env.moqi_profile_stats
   stats.work_ms = stats.work_ms + elapsed_ms
   if elapsed_ms > stats.max_ms then
      stats.max_ms = elapsed_ms
   end
end

function M.finish(env, candidates)
   if not M.enabled(env) then
      return
   end

   local stats = env.moqi_profile_stats
   local call_work_ms = stats.work_ms - stats.previous_work_ms
   stats.previous_work_ms = stats.work_ms
   stats.calls = stats.calls + 1
   stats.candidates = stats.candidates + candidates

   local should_log = false
   if env.moqi_profile_log_every > 0 and stats.calls % env.moqi_profile_log_every == 0 then
      should_log = true
   end
   if env.moqi_profile_slow_ms > 0 and call_work_ms >= env.moqi_profile_slow_ms then
      should_log = true
   end
   if not should_log then
      return
   end

   local avg_ms = 0
   local avg_candidates = 0
   if stats.calls > 0 then
      avg_ms = stats.work_ms / stats.calls
      avg_candidates = stats.candidates / stats.calls
   end

   log.warning(string.format(
      "moqi_profile: name=%s calls=%d candidates=%d avg_candidates=%.2f last_ms=%.3f work_ms=%.3f avg_ms=%.3f max_item_ms=%.3f",
      env.moqi_profile_name,
      stats.calls,
      stats.candidates,
      avg_candidates,
      call_work_ms,
      stats.work_ms,
      avg_ms,
      stats.max_ms
   ))
end

return M

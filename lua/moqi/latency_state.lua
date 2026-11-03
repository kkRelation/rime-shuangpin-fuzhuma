local M = {
   next_session_id = 0,
   sessions = {},
}

local session_property = "moqi_latency_session"

local function new_session(id)
   return {
      id = id,
      key_at = nil,
      key_input = "",
      keycode = 0,
      key_seq = 0,
      candidate_logged_for_key = {},
      candidate_elapsed_ms = {},
      calls = 0,
   }
end

function M.attach(env)
   local context = env.engine.context
   local id = context:get_property(session_property)
   if not id or id == "" then
      M.next_session_id = M.next_session_id + 1
      id = tostring(M.next_session_id)
      context:set_property(session_property, id)
   end

   local session = M.sessions[id]
   if not session then
      session = new_session(id)
      M.sessions[id] = session
   end
   return session
end

function M.detach(env)
   local context = env.engine.context
   local id = context:get_property(session_property)
   if id and id ~= "" then
      M.sessions[id] = nil
      context:set_property(session_property, "")
   end
end

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

function M.should_log(env, session, elapsed_ms)
   session.calls = session.calls + 1
   local log_every = M.log_every(env)
   return elapsed_ms >= M.threshold_ms(env) or (log_every > 0 and session.calls % log_every == 0)
end

return M

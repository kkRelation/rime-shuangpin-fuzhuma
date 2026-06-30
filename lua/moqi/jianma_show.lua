-- 参考魔然 https://github.com/rimeinn/rime-moran/blob/main/lua/moran_hint_filter.lua
-- 参考星空键道 https://github.com/xkjd27/rime_jd27c/blob/e38a8c5d010d5a3933e6d6d8265c0cf7b56bfcca/rime/lua/jd27_hint.lua
-- 当用户用全码 "womf" 输入"我们"时，回显简码提示 "wm"。

local Module = {}

local DICT_NAME = "moqi_single"
local CACHE_MISS = false

local function debug(env, message)
   if env.jianma_show_debug then
      log.info("jianma_show: " .. message)
   end
end

local function append_hint(cand, hint)
   if not hint or hint == "" then
      return
   end

   local comment = cand.comment or ""
   local suffix = "! " .. hint
   if comment:find(suffix, 1, true) then
      return
   end

   if comment ~= "" then
      cand.comment = comment .. suffix
   else
      cand.comment = hint
   end
end

local function pick_hint(all_codes, word_len, current_input)
   local short_codes = {}
   local four_char_codes = {}
   local other_codes = {}

   for code in all_codes:gmatch("%S+") do
      if #code <= 2 then
         short_codes[#short_codes + 1] = code
      elseif word_len <= 4 then
         if word_len == 4 and #code == 4 then
            four_char_codes[#four_char_codes + 1] = code
         elseif #code < 4 and code ~= current_input then
            other_codes[#other_codes + 1] = code
         end
      end
   end

   if #short_codes > 0 then
      return table.concat(short_codes, " ")
   end
   if word_len == 4 and #four_char_codes > 0 then
      return table.concat(four_char_codes, " ")
   end
   if #other_codes > 0 then
      return table.concat(other_codes, " ")
   end
   return nil
end

local function should_lookup(word_len, current_input_length)
   if word_len == 1 then
      return false
   end
   if word_len >= 2 and word_len <= 4 then
      return current_input_length >= 4
   end
   return true
end

local function reset_cache_if_needed(env, current_input)
   if env.jianma_show_input == current_input then
      return
   end

   env.jianma_show_input = current_input
   env.jianma_show_cache = {}
end

local function lookup_hint(env, word, word_len, current_input, current_input_length)
   if not should_lookup(word_len, current_input_length) then
      return nil
   end

   local cache = env.jianma_show_cache
   local cached = cache[word]
   if cached ~= nil then
      if cached == CACHE_MISS then
         return nil
      end
      return cached
   end

   debug(env, "lookup " .. word .. " for input " .. current_input)
   local all_codes = env.custom_phrase_reverse:lookup(word)
   if not all_codes then
      cache[word] = CACHE_MISS
      return nil
   end

   local hint = pick_hint(all_codes, word_len, current_input)
   cache[word] = hint or CACHE_MISS
   return hint
end

function Module.init(env)
   local config = env.engine.schema.config
   env.jianma_show_debug = config:get_bool("jianma_show/debug") or false
   env.jianma_show_input = nil
   env.jianma_show_cache = {}

   -- 这里必须先在 build 文件夹下构建一个 xxx.reverse.bin 二进制文件。
   env.custom_phrase_reverse = ReverseLookup(DICT_NAME)
   if env.custom_phrase_reverse then
      debug(env, "ReverseLookup created for " .. DICT_NAME)
   else
      log.warning("jianma_show: failed to create ReverseLookup for " .. DICT_NAME)
      log.warning("jianma_show: make sure moqi_single.reverse.bin exists in build folder")
   end
end

function Module.fini(env)
   env.custom_phrase_reverse = nil
   env.jianma_show_cache = nil
end

function Module.func(translation, env)
   if not env.custom_phrase_reverse then
      for cand in translation:iter() do
         yield(cand)
      end
      return
   end

   local current_input = env.engine.context.input or ""
   local current_input_length = #current_input
   reset_cache_if_needed(env, current_input)

   for cand in translation:iter() do
      local gcand = cand:get_genuine()
      local word = gcand.text or ""
      local word_len = utf8.len(word) or 0
      local hint = lookup_hint(env, word, word_len, current_input, current_input_length)
      append_hint(gcand, hint)
      yield(cand)
   end
end

return Module

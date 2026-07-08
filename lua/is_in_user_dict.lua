-- 根据是否在用户词典，在结尾加上一个星号 *
-- is_in_user_dict: true           输入过的内容
-- is_in_user_dict: false 或不写    未输入过的内容

local M = {}
local profile = require("moqi.profile")

function M.init(env)
    local config = env.engine.schema.config
    profile.init(env, "is_in_user_dict")
    env.name_space = env.name_space:gsub('^*', '')
    M.is_in_user_dict = config:get_bool(env.name_space) or true
end

function M.func(input, env)
    local cand_count = 0
    for cand in input:iter() do
        cand_count = cand_count + 1
        local profile_started_at = profile.now(env)
        -- 用户词库，加上*号
        if cand.type == "user_phrase" then
            cand.comment = cand.comment .. '*'
        end
        -- 用户置顶词
        -- if cand.type == "user_table" then
        --     cand.comment = cand.comment .. '⚡️'
        -- end

        -- 整句联想，加上𑄗符号
        if cand.type == 'sentence' then
            cand.comment = cand.comment .. '∞'
        end
        profile.add_work(env, profile_started_at)
        yield(cand)
    end
    profile.finish(env, cand_count)
end

return M

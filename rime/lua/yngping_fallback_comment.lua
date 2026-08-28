-- lua/yngping_fallback_comment.lua
--
-- 例如：
--   貓 -> ma53 mau55
--   咪 -> mi55
--
--   貓咪 -> ma53|mau55 mi55

local M = {}

function M.init(env)
  env.db = ReverseDb("build/hokchew.reverse.bin")
end

local function lookup_char(db, char)
  local codes = db:lookup(char)

  -- 无读音时以 ? 标识
  if codes == nil or codes == "" then
    return "?"
  end

  -- 同一个字的多个读音用 | 分隔
  return (codes:gsub("%s+", "|"))
end

local function fallback_comment(db, text)
  local result = {}
  local count = 0

  for _, cp in utf8.codes(text) do
    count = count + 1

    local char = utf8.char(cp)
    local codes = lookup_char(db, char)

    result[#result + 1] = codes
  end

  -- fallback 只管多字词
  -- 单字交给 yngping_char_comment
  if count <= 1 then
    return nil
  end

  -- 不同汉字之间用空格分隔
  return table.concat(result, " ")
end

function M.func(input, env)
  local context = env.engine.context
  local composition = context.composition
  local segment = composition:back()

  -- 只处理普通话拼音反查 segment
  if segment == nil or not segment:has_tag("pinyin") then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end

  for cand in input:iter() do
    -- 已经由前面的 reverse_lookup_filter 命中 comment
    if cand.comment ~= nil and cand.comment ~= "" then
      yield(cand)
    else
      local comment = fallback_comment(env.db, cand.text)

      if comment ~= nil then
        cand:get_genuine().comment = comment
      end

      yield(cand)
    end
  end
end

return M

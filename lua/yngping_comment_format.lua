-- lua/yngping_comment_format.lua
--
-- 统一格式化榕拼反查 comment
--
-- 1. 单字：
--      ma53 mau55 miu53
--    ->
--      <mà> <mau> <mìu>
--
-- 2. 已收录词汇：
--      huang55+ny53 huang55+sy53
--    ->
--      <huang nǜ> <huang sǜ>
--
-- 3. 未收录多字 fallback：
--      ma53|mau55|miu53 mi33|mi55
--    ->
--      <mà·mau·mìu> <mī·mi>

local M = {}
local renderer = require("yngping_render")

local function split(text, sep)
  local result = {}
  local start = 1

  while true do
    local pos = text:find(sep, start, true)

    if pos == nil then
      local part = text:sub(start)

      if part ~= "" then
        result[#result + 1] = part
      end

      break
    end

    local part = text:sub(start, pos - 1)

    if part ~= "" then
      result[#result + 1] = part
    end

    start = pos + #sep
  end

  return result
end

local function split_groups(text)
  local result = {}

  for group in text:gmatch("%S+") do
    result[#result + 1] = group
  end

  return result
end

local function format_group(group)
  -- 已收录词汇的一条完整读音
  -- huang55+ny53 -> <huang nǜ>
  if group:find("+", 1, true) ~= nil then
    local syllables = split(group, "+")
    local rendered = {}

    for _, syllable in ipairs(syllables) do
      rendered[#rendered + 1] = renderer.render_syllable(syllable)
    end

    return "<" .. table.concat(rendered, " ") .. ">"
  end

  -- 单字 native / fallback 的一个字
  -- ma53|mau55 -> <mà·mau>
  local readings = split(group, "|")
  local rendered = {}

  for _, reading in ipairs(readings) do
    rendered[#rendered + 1] = renderer.render_syllable(reading)
  end

  return "<" .. table.concat(rendered, "·") .. ">"
end

local function format_comment(comment)
  local groups = split_groups(comment)

  if #groups == 0 then
    return nil
  end

  local result = {}

  for _, group in ipairs(groups) do
    result[#result + 1] = format_group(group)
  end

  return table.concat(result, " ")
end

M.format_comment = format_comment

function M.func(input, env)
  local context = env.engine.context
  local composition = context.composition
  local segment = composition:back()

  -- 只处理普通话拼音反查
  if segment == nil or not segment:has_tag("pinyin") then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end

  for cand in input:iter() do
    if cand.comment ~= nil and cand.comment ~= "" then
      local comment = format_comment(cand.comment)

      if comment ~= nil then
        cand:get_genuine().comment = comment
      end
    end

    yield(cand)
  end
end

return M

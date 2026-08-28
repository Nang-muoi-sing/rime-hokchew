-- lua/yngping_render.lua

local M = {}

local TONES = { "", "0", "21", "213", "24", "242", "33", "5", "53", "55" }

local GLIDE_DETAILS = {
  i = { cursive = "i" },
  u = { cursive = "u" },
  y = { cursive = "ü" },
  [""] = { cursive = "" },
}

local NUCLEUS_DETAILS = {
  a = { peak = "a", cursive = "~" },
  e = { peak = "e", cursive = "~" },
  o = { peak = "o", cursive = "~" },
  oo = { peak = "oo", cursive = "~" },
  i = { peak = "i", cursive = "~" },
  u = { peak = "u", cursive = "~" },
  y = { peak = "y", cursive = "~" },
  eo = { peak = "eo", cursive = "~" },
  au = { peak = "a", cursive = "~u" },
  eu = { peak = "e", cursive = "~u" },
  iu = { peak = "i", cursive = "~u" },
  ai = { peak = "a", cursive = "~i" },
  ui = { peak = "u", cursive = "~i" },
  ei = { peak = "e", cursive = "~i" },
  ou = { peak = "o", cursive = "~u" },
  eoy = { peak = "eo", cursive = "~ü" },
  ooy = { peak = "oo", cursive = "~ü" },
  uo = { peak = "u", cursive = "~o" },
  yo = { peak = "y", cursive = "~o" },
  oi = { peak = "o", cursive = "~i" },
  oou = { peak = "oo", cursive = "~u" },
  [""] = { peak = "ng", cursive = "~" },
}

local VOWEL_CURSIVE_MAP = {
  a_ = "a",
  a_0 = "ạ",
  a_33 = "ā",
  a_55 = "a",
  a_21 = "ǎ",
  a_213 = "ǎ",
  a_24 = "á",
  a_53 = "à",
  a_242 = "â",
  a_5 = "a",
  e_ = "e",
  e_0 = "ẹ",
  e_33 = "ē",
  e_55 = "e",
  e_21 = "ě",
  e_213 = "ě",
  e_24 = "é",
  e_53 = "è",
  e_242 = "ê",
  e_5 = "e",
  o_ = "o",
  o_0 = "ọ",
  o_33 = "ō",
  o_55 = "o",
  o_21 = "ǒ",
  o_213 = "ǒ",
  o_24 = "ó",
  o_53 = "ò",
  o_242 = "ô",
  o_5 = "o",
  oo_ = "ö",
  oo_0 = "ọ̈",
  oo_33 = "ȫ",
  oo_55 = "ö",
  oo_21 = "ö̌",
  oo_213 = "ö̌",
  oo_24 = "ö́",
  oo_53 = "ö̀",
  oo_242 = "ö̂",
  oo_5 = "ö",
  eo_ = "ë",
  eo_0 = "ẹ̈",
  eo_33 = "ë̄",
  eo_55 = "ë",
  eo_21 = "ë̌",
  eo_213 = "ë̌",
  eo_24 = "ë́",
  eo_53 = "ë̀",
  eo_242 = "ë̂",
  eo_5 = "ë",
  i_ = "i",
  i_0 = "ị",
  i_33 = "ī",
  i_55 = "i",
  i_21 = "ǐ",
  i_213 = "ǐ",
  i_24 = "í",
  i_53 = "ì",
  i_242 = "î",
  i_5 = "i",
  u_ = "u",
  u_0 = "ụ",
  u_33 = "ū",
  u_55 = "u",
  u_21 = "ǔ",
  u_213 = "ǔ",
  u_24 = "ú",
  u_53 = "ù",
  u_242 = "û",
  u_5 = "u",
  y_ = "ü",
  y_0 = "ụ̈",
  y_33 = "ǖ",
  y_55 = "ü",
  y_21 = "ǚ",
  y_213 = "ǚ",
  y_24 = "ǘ",
  y_53 = "ǜ",
  y_242 = "ü̂",
  y_5 = "ü",
  ng_ = "ng",
  ng_0 = "ṇg",
  ng_33 = "n̄g",
  ng_55 = "ng",
  ng_21 = "ňg",
  ng_213 = "ňg",
  ng_24 = "ńg",
  ng_53 = "ǹg",
  ng_242 = "n̂g",
  ng_5 = "ng",
}

local FINAL_DETAILS = {
  a = { glide = "", nucleus = "a", coda = "" },
  ia = { glide = "i", nucleus = "a", coda = "" },
  ua = { glide = "u", nucleus = "a", coda = "" },
  ang = { glide = "", nucleus = "a", coda = "ng" },
  iang = { glide = "i", nucleus = "a", coda = "ng" },
  uang = { glide = "u", nucleus = "a", coda = "ng" },
  ah = { glide = "", nucleus = "a", coda = "h" },
  ak = { glide = "", nucleus = "a", coda = "k" },
  iah = { glide = "i", nucleus = "a", coda = "h" },
  iak = { glide = "i", nucleus = "a", coda = "k" },
  uah = { glide = "u", nucleus = "a", coda = "h" },
  uak = { glide = "u", nucleus = "a", coda = "k" },
  e = { glide = "", nucleus = "e", coda = "" },
  ie = { glide = "i", nucleus = "e", coda = "" },
  ieng = { glide = "i", nucleus = "e", coda = "ng" },
  eh = { glide = "", nucleus = "e", coda = "h" },
  ieh = { glide = "i", nucleus = "e", coda = "h" },
  iek = { glide = "i", nucleus = "e", coda = "k" },
  o = { glide = "", nucleus = "o", coda = "" },
  uo = { glide = "u", nucleus = "o", coda = "" },
  yo = { glide = "y", nucleus = "o", coda = "" },
  uong = { glide = "u", nucleus = "o", coda = "ng" },
  yong = { glide = "y", nucleus = "o", coda = "ng" },
  oh = { glide = "", nucleus = "o", coda = "h" },
  uoh = { glide = "u", nucleus = "o", coda = "h" },
  uok = { glide = "u", nucleus = "o", coda = "k" },
  yoh = { glide = "y", nucleus = "o", coda = "h" },
  yok = { glide = "y", nucleus = "o", coda = "k" },
  oo = { glide = "", nucleus = "oo", coda = "" },
  ooh = { glide = "", nucleus = "oo", coda = "h" },
  eo = { glide = "", nucleus = "eo", coda = "" },
  eoh = { glide = "", nucleus = "eo", coda = "h" },
  au = { glide = "", nucleus = "au", coda = "" },
  eu = { glide = "", nucleus = "eu", coda = "" },
  iu = { glide = "", nucleus = "iu", coda = "" },
  ai = { glide = "", nucleus = "ai", coda = "" },
  uai = { glide = "u", nucleus = "ai", coda = "" },
  ui = { glide = "", nucleus = "ui", coda = "" },
  i = { glide = "", nucleus = "i", coda = "" },
  u = { glide = "", nucleus = "u", coda = "" },
  y = { glide = "", nucleus = "y", coda = "" },
  ing = { glide = "", nucleus = "i", coda = "ng" },
  ung = { glide = "", nucleus = "u", coda = "ng" },
  yng = { glide = "", nucleus = "y", coda = "ng" },
  ih = { glide = "", nucleus = "i", coda = "h" },
  ik = { glide = "", nucleus = "i", coda = "k" },
  uh = { glide = "", nucleus = "u", coda = "h" },
  uk = { glide = "", nucleus = "u", coda = "k" },
  yh = { glide = "", nucleus = "y", coda = "h" },
  yk = { glide = "", nucleus = "y", coda = "k" },
  ei = { glide = "", nucleus = "ei", coda = "" },
  ou = { glide = "", nucleus = "ou", coda = "" },
  eoy = { glide = "", nucleus = "eoy", coda = "" },
  eing = { glide = "", nucleus = "ei", coda = "ng" },
  oung = { glide = "", nucleus = "ou", coda = "ng" },
  eoyng = { glide = "", nucleus = "eoy", coda = "ng" },
  eih = { glide = "", nucleus = "ei", coda = "h" },
  eik = { glide = "", nucleus = "ei", coda = "k" },
  ouh = { glide = "", nucleus = "ou", coda = "h" },
  ouk = { glide = "", nucleus = "ou", coda = "k" },
  eoyh = { glide = "", nucleus = "eoy", coda = "h" },
  eoyk = { glide = "", nucleus = "eoy", coda = "k" },
  ooy = { glide = "", nucleus = "ooy", coda = "" },
  aing = { glide = "", nucleus = "ai", coda = "ng" },
  ooung = { glide = "", nucleus = "oou", coda = "ng" },
  ooyng = { glide = "", nucleus = "ooy", coda = "ng" },
  aik = { glide = "", nucleus = "ai", coda = "k" },
  oouk = { glide = "", nucleus = "oou", coda = "k" },
  ooyk = { glide = "", nucleus = "ooy", coda = "k" },
  ng = { glide = "", nucleus = "", coda = "ng" },
  ieu = { glide = "i", nucleus = "eu", coda = "" },
  uoi = { glide = "u", nucleus = "oi", coda = "" },
  iau = { glide = "i", nucleus = "au", coda = "" },
  iauh = { glide = "i", nucleus = "au", coda = "h" },
  am = { glide = "", nucleus = "a", coda = "m" },
  an = { glide = "", nucleus = "a", coda = "n" },
  iam = { glide = "i", nucleus = "a", coda = "m" },
  ian = { glide = "i", nucleus = "a", coda = "n" },
  uam = { glide = "u", nucleus = "a", coda = "m" },
  uan = { glide = "u", nucleus = "a", coda = "n" },
  ap = { glide = "", nucleus = "a", coda = "p" },
  at = { glide = "", nucleus = "a", coda = "t" },
  iap = { glide = "i", nucleus = "a", coda = "p" },
  iat = { glide = "i", nucleus = "a", coda = "t" },
  uap = { glide = "u", nucleus = "a", coda = "p" },
  uat = { glide = "u", nucleus = "a", coda = "t" },
  iem = { glide = "i", nucleus = "e", coda = "m" },
  ien = { glide = "i", nucleus = "e", coda = "n" },
  ep = { glide = "", nucleus = "e", coda = "p" },
  et = { glide = "", nucleus = "e", coda = "t" },
  ek = { glide = "", nucleus = "e", coda = "k" },
  iep = { glide = "i", nucleus = "e", coda = "p" },
  iet = { glide = "i", nucleus = "e", coda = "t" },
  uom = { glide = "u", nucleus = "o", coda = "m" },
  uon = { glide = "u", nucleus = "o", coda = "n" },
  yom = { glide = "y", nucleus = "o", coda = "m" },
  yon = { glide = "y", nucleus = "o", coda = "n" },
  op = { glide = "", nucleus = "o", coda = "p" },
  ot = { glide = "", nucleus = "o", coda = "t" },
  ok = { glide = "", nucleus = "o", coda = "k" },
  uop = { glide = "u", nucleus = "o", coda = "p" },
  uot = { glide = "u", nucleus = "o", coda = "t" },
  yop = { glide = "y", nucleus = "o", coda = "p" },
  yot = { glide = "y", nucleus = "o", coda = "t" },
  oop = { glide = "", nucleus = "oo", coda = "p" },
  oot = { glide = "", nucleus = "oo", coda = "t" },
  ook = { glide = "", nucleus = "oo", coda = "k" },
  eop = { glide = "", nucleus = "eo", coda = "p" },
  eot = { glide = "", nucleus = "eo", coda = "t" },
  eok = { glide = "", nucleus = "eo", coda = "k" },
  im = { glide = "", nucleus = "i", coda = "m" },
  ["in"] = { glide = "", nucleus = "i", coda = "n" },
  um = { glide = "", nucleus = "u", coda = "m" },
  un = { glide = "", nucleus = "u", coda = "n" },
  ym = { glide = "", nucleus = "y", coda = "m" },
  yn = { glide = "", nucleus = "y", coda = "n" },
  eim = { glide = "", nucleus = "ei", coda = "m" },
  ein = { glide = "", nucleus = "ei", coda = "n" },
  oum = { glide = "", nucleus = "ou", coda = "m" },
  oun = { glide = "", nucleus = "ou", coda = "n" },
  eoym = { glide = "", nucleus = "eoy", coda = "m" },
  eoyn = { glide = "", nucleus = "eoy", coda = "n" },
  ip = { glide = "", nucleus = "i", coda = "p" },
  it = { glide = "", nucleus = "i", coda = "t" },
  up = { glide = "", nucleus = "u", coda = "p" },
  ut = { glide = "", nucleus = "u", coda = "t" },
  yp = { glide = "", nucleus = "y", coda = "p" },
  yt = { glide = "", nucleus = "y", coda = "t" },
  eip = { glide = "", nucleus = "ei", coda = "p" },
  eit = { glide = "", nucleus = "ei", coda = "t" },
  oup = { glide = "", nucleus = "ou", coda = "p" },
  out = { glide = "", nucleus = "ou", coda = "t" },
  eoyp = { glide = "", nucleus = "eoy", coda = "p" },
  eoyt = { glide = "", nucleus = "eoy", coda = "t" },
}

local INITIALS = {
  "nj",
  "ng",
  "b",
  "p",
  "m",
  "d",
  "t",
  "n",
  "l",
  "s",
  "z",
  "c",
  "g",
  "k",
  "h",
  "w",
  "j",
  "",
}

local function replace_once(text, old, new)
  return (text:gsub(old, new, 1))
end

local NUCLEUS_CURSIVE_MAP = {}

for nucleus, details in pairs(NUCLEUS_DETAILS) do
  for _, tone in ipairs(TONES) do
    local tone_vowel = VOWEL_CURSIVE_MAP[details.peak .. "_" .. tone] or details.peak
    NUCLEUS_CURSIVE_MAP[nucleus .. "_" .. tone] =
      replace_once(details.cursive, "~", tone_vowel)
  end
end

local function parse_syllable(code)
  local raw = code
  local fixed_tone = true

  if raw:match("^%{.+%}$") then
    fixed_tone = false
    raw = raw:sub(2, -2)
  end

  local base = raw
  local tone = ""

  for _, candidate in ipairs({ "213", "242", "21", "24", "33", "53", "55", "0", "5" }) do
    if raw:sub(-#candidate) == candidate then
      base = raw:sub(1, #raw - #candidate)
      tone = fixed_tone and candidate or ""
      break
    end
  end

  if base == "" then
    return nil
  end

  for _, initial in ipairs(INITIALS) do
    if initial == "" or base:sub(1, #initial) == initial then
      local final = base:sub(#initial + 1)

      if FINAL_DETAILS[final] ~= nil then
        return { initial = initial, final = final, tone = tone, fixed_tone = fixed_tone }
      end
    end
  end

  return nil
end

function M.render_syllable(code)
  local syllable = parse_syllable(code)

  if syllable == nil then
    return code
  end

  local final_detail = FINAL_DETAILS[syllable.final]
  local glide = GLIDE_DETAILS[final_detail.glide].cursive
  local nucleus_with_tone =
    NUCLEUS_CURSIVE_MAP[final_detail.nucleus .. "_" .. syllable.tone]

  if nucleus_with_tone == nil then
    return code
  end

  local coda = final_detail.nucleus == "" and "" or final_detail.coda
  local rendered = syllable.initial .. glide .. nucleus_with_tone .. coda

  if not syllable.fixed_tone then
    return "{" .. rendered .. "}"
  end

  return rendered
end

function M.render_text(text)
  return (text:gsub("[{}%w]+", M.render_syllable))
end

return M

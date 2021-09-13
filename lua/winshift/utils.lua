local api = vim.api
local M = {}

function M._echo_multiline(msg)
  for _, s in ipairs(vim.fn.split(msg, "\n")) do
    vim.cmd("echom '" .. s:gsub("'", "''") .. "'")
  end
end

function M.info(msg)
  vim.cmd("echohl Directory")
  M._echo_multiline("[WinShift.nvim] " .. msg)
  vim.cmd("echohl None")
end

function M.warn(msg)
  vim.cmd("echohl WarningMsg")
  M._echo_multiline("[WinShift.nvim] " .. msg)
  vim.cmd("echohl None")
end

function M.err(msg)
  vim.cmd("echohl ErrorMsg")
  M._echo_multiline("[WinShift.nvim] " .. msg)
  vim.cmd("echohl None")
end

function M.no_win_event_call(cb)
  local last = vim.opt.eventignore._value
  vim.opt.eventignore = (
    "WinEnter,WinLeave,WinNew,WinClosed,BufEnter,BufLeave"
    .. (last ~= "" and "," .. last or "")
  )
  local ok, err = pcall(cb)
  vim.opt.eventignore = last
  return ok, err
end

---Escape a string for use as a pattern.
---@param s string
---@return string
function M.pattern_esc(s)
  local result = string.gsub(s, "[%(|%)|%%|%[|%]|%-|%.|%?|%+|%*|%^|%$]", {
    ["%"] = "%%",
    ["-"] = "%-",
    ["("] = "%(",
    [")"] = "%)",
    ["."] = "%.",
    ["["] = "%[",
    ["]"] = "%]",
    ["?"] = "%?",
    ["+"] = "%+",
    ["*"] = "%*",
    ["^"] = "%^",
    ["$"] = "%$",
  })
  return result
end

---Create a shallow copy of a portion of a list.
---@param t table
---@param first integer First index, inclusive
---@param last integer Last index, inclusive
---@return any[]
function M.tbl_slice(t, first, last)
  local slice = {}
  for i = first, last or #t, 1 do
    table.insert(slice, t[i])
  end

  return slice
end

function M.tbl_concat(...)
  local result = {}
  local n = 0

  for _, t in ipairs({ ... }) do
    for i, v in ipairs(t) do
      result[n + i] = v
    end
    n = n + #t
  end

  return result
end

function M.tbl_clone(t)
  if not t then
    return
  end
  local clone = {}

  for k, v in pairs(t) do
    clone[k] = v
  end

  return clone
end

function M.tbl_deep_clone(t)
  if not t then
    return
  end
  local clone = {}

  for k, v in pairs(t) do
    if type(v) == "table" then
      clone[k] = M.tbl_deep_clone(v)
    else
      clone[k] = v
    end
  end

  return clone
end

function M.tbl_deep_equals(t1, t2)
  if not (t1 and t2) then
    return false
  end

  local function recurse(t11, t22)
    if #t11 ~= #t22 then
      return false
    end

    local seen = {}
    for key, value in pairs(t11) do
      seen[key] = true
      if type(value) == "table" then
        if type(t22[key]) ~= "table" then
          return false
        end
        if not recurse(value, t22[key]) then
          return false
        end
      else
        if not (value == t22[key]) then
          return false
        end
      end
    end

    for key, _ in pairs(t22) do
      if not seen[key] then
        return false
      end
    end

    return true
  end

  return recurse(t1, t2)
end

function M.tbl_pack(...)
  return { n = select("#", ...), ... }
end

function M.tbl_unpack(t, i, j)
  return unpack(t, i or 1, j or t.n or #t)
end

function M.tbl_indexof(t, v)
  for i, vt in ipairs(t) do
    if vt == v then
      return i
    end
  end
  return -1
end

function M.tbl_clear(t)
  for k, _ in pairs(t) do
    t[k] = nil
  end
end

function M.clear_prompt()
  vim.cmd("norm! :esc<CR>")
end

function M.input_char(prompt, opt)
  opt = vim.tbl_extend("keep", opt or {}, {
    clear_prompt = true,
    allow_non_ascii = false
  })

  if prompt then
    vim.api.nvim_echo({ { prompt } }, false, {})
  end

  local c
  if not opt.allow_non_ascii then
    while type(c) ~= "number" do
      c = vim.fn.getchar()
    end
  else
    c = vim.fn.getchar()
  end

  if opt.clear_prompt then
    M.clear_prompt()
  end

  local s = type(c) == "number" and vim.fn.nr2char(c) or nil
  local raw = type(c) == "number" and s or c
  return s, raw
end

function M.input(prompt, default, completion)
  local v = vim.fn.input({
    prompt = prompt,
    default = default,
    completion = completion,
    cancelreturn = "__INPUT_CANCELLED__",
  })
  M.clear_prompt()
  return v
end

function M.raw_key(vim_key)
  return api.nvim_eval(string.format([["\%s"]], vim_key))
end

---HACK: workaround for inconsistent behavior from `vim.opt_local`.
---@see [Neovim issue](https://github.com/neovim/neovim/issues/14670)
---@param winids number[]|number Either a list of winids, or a single winid (0 for current window).
---@param option string
---@param value string[]|string
---@param opt table
function M.set_local(winids, option, value, opt)
  local last_winid = api.nvim_get_current_win()
  local rhs
  opt = vim.tbl_extend("keep", opt or {}, { restore_cursor = true })

  if type(value) == "boolean" then
    if value == false then
      rhs = "no" .. option
    else
      rhs = option
    end
  else
    rhs = option .. "=" .. (type(value) == "table" and table.concat(value, ",") or value)
  end

  if type(winids) ~= "table" then
    winids = { winids }
  end

  M.no_win_event_call(function()
    for _, id in ipairs(winids) do
      local nr = tostring(api.nvim_win_get_number(id == 0 and last_winid or id))
      local cmd = string.format("%swindo setlocal ", nr)
      vim.cmd(cmd .. rhs)
    end

    if opt.restore_cursor then
      api.nvim_set_current_win(last_winid)
    end
  end)
end

---@param winids number[]|number Either a list of winids, or a single winid (0 for current window).
---@param option string
---@param opt table
function M.unset_local(winids, option, opt)
  local last_winid = api.nvim_get_current_win()
  opt = vim.tbl_extend("keep", opt or {}, { restore_cursor = true })

  if type(winids) ~= "table" then
    winids = { winids }
  end

  M.no_win_event_call(function()
    for _, id in ipairs(winids) do
      local nr = tostring(api.nvim_win_get_number(id == 0 and last_winid or id))
      vim.cmd(string.format("%swindo set %s<", nr, option))
    end

    if opt.restore_cursor then
      api.nvim_set_current_win(last_winid)
    end
  end)
end

return M

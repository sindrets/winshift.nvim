local api = vim.api
local M = {}

local setlocal_opr_templates = {
  set = [[setl ${option}=${value}]],
  remove = [[exe 'setl ${option}-=${value}']],
  append = [[exe 'setl ${option}=' . (&${option} == "" ? "" : &${option} . ",") . '${value}']],
  prepend = [[exe 'setl ${option}=${value}' . (&${option} == "" ? "" : "," . &${option})]],
}

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

---Simple string templating
---Example template: "${name} is ${value}"
---@param str string Template string
---@param table table Key-value pairs to replace in the string
function M.str_template(str, table)
  return (str:gsub("($%b{})", function(w)
    return table[w:sub(3, -2)] or w
  end))
end

function M.clear_prompt()
  vim.cmd("norm! :esc<CR>")
end

function M.input_char(prompt, opt)
  opt = vim.tbl_extend("keep", opt or {}, {
    clear_prompt = true,
    allow_non_ascii = false,
    prompt_hl = nil,
  })

  if prompt then
    vim.api.nvim_echo({ { prompt, opt.prompt_hl } }, false, {})
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
---`opt` fields:
---   @tfield method '"set"'|'"remove"'|'"append"'|'"prepend"' Assignment method. (default: "set")
---@overload fun(winids: number[]|number, option: string, value: string[]|string|boolean, opt?: any)
---@overload fun(winids: number[]|number, map: table<string, string[]|string|boolean>, opt?: table)
function M.set_local(winids, x, y, z)
  if type(winids) ~= "table" then
    winids = { winids }
  end

  local map, opt
  if y == nil or type(y) == "table" then
    map = x
    opt = y
  else
    map = { [x] = y }
    opt = z
  end

  opt = vim.tbl_extend("keep", opt or {}, { method = "set" })

  local cmd
  local ok, err = M.no_win_event_call(function()
    for _, id in ipairs(winids) do
      api.nvim_win_call(id, function()
        for option, value in pairs(map) do
          local o = opt

          if type(value) == "boolean" then
            cmd = string.format("setl %s%s", value and "" or "no", option)
          else
            if type(value) == "table" then
              ---@diagnostic disable-next-line: undefined-field
              o = vim.tbl_extend("force", opt, value.opt or {})
              value = table.concat(value, ",")
            end

            cmd = M.str_template(
              setlocal_opr_templates[o.method],
              { option = option, value = tostring(value):gsub("'", "''") }
            )
          end

          vim.cmd(cmd)
        end
      end)
    end
  end)

  if not ok then
    error(err)
  end
end

---@param winids number[]|number Either a list of winids, or a single winid (0 for current window).
---@param option string
function M.unset_local(winids, option)
  if type(winids) ~= "table" then
    winids = { winids }
  end

  M.no_win_event_call(function()
    for _, id in ipairs(winids) do
      api.nvim_win_call(id, function()
        vim.cmd(string.format("set %s<", option))
      end)
    end
  end)
end

return M

local config = require("winshift.config")
local api = vim.api
local M = {}

--#region TYPES

---@class HiSpec
---@field fg string
---@field bg string
---@field ctermfg integer
---@field ctermbg integer
---@field gui string
---@field sp string
---@field blend integer
---@field default boolean

---@class HiLinkSpec
---@field force boolean
---@field default boolean

--#endregion

---@param name string Syntax group name.
---@param attr string Attribute name.
---@param trans boolean Translate the syntax group (follows links).
function M.get_hl_attr(name, attr, trans)
  local id = api.nvim_get_hl_id_by_name(name)
  if id and trans then
    id = vim.fn.synIDtrans(id)
  end
  if not id then
    return
  end

  local value = vim.fn.synIDattr(id, attr)
  if not value or value == "" then
    return
  end

  return value
end

---@param groups string|string[] Syntax group name, or an ordered list of
---groups where the first found value will be returned.
---@param trans boolean Translate the syntax group (follows links). True by default.
function M.get_fg(groups, trans)
  if type(trans) ~= "boolean" then trans = true end

  if type(groups) == "table" then
    local v
    for _, group in ipairs(groups) do
      v = M.get_hl_attr(group, "fg", trans)
      if v then return v end
    end
    return
  end

  return M.get_hl_attr(groups, "fg", trans)
end

---@param groups string|string[] Syntax group name, or an ordered list of
---groups where the first found value will be returned.
---@param trans boolean Translate the syntax group (follows links). True by default.
function M.get_bg(groups, trans)
  if type(trans) ~= "boolean" then trans = true end

  if type(groups) == "table" then
    local v
    for _, group in ipairs(groups) do
      v = M.get_hl_attr(group, "bg", trans)
      if v then return v end
    end
    return
  end

  return M.get_hl_attr(groups, "bg", trans)
end

---@param groups string|string[] Syntax group name, or an ordered list of
---groups where the first found value will be returned.
---@param trans boolean Translate the syntax group (follows links). True by default.
function M.get_gui(groups, trans)
  if type(trans) ~= "boolean" then trans = true end
  if type(groups) ~= "table" then groups = { groups } end

  local hls
  for _, group in ipairs(groups) do
    hls = {}
    local attributes = {
      "bold",
      "italic",
      "reverse",
      "standout",
      "underline",
      "undercurl",
      "strikethrough"
    }

    for _, attr in ipairs(attributes) do
      if M.get_hl_attr(group, attr, trans) == "1" then
        table.insert(hls, attr)
      end
    end

    if #hls > 0 then
      return table.concat(hls, ",")
    end
  end
end

---@param group string Syntax group name.
---@param opt HiSpec
function M.hi(group, opt)
  local use_tc = vim.o.termguicolors
  local g = use_tc and "gui" or "cterm"

  if not use_tc then
    if opt.ctermfg then
      opt.fg = opt.ctermfg
    end
    if opt.ctermbg then
      opt.bg = opt.ctermbg
    end
  end

  vim.cmd(string.format(
    "hi %s %s %s %s %s %s %s",
    opt.default and "def" or "",
    group,
    opt.fg and (g .. "fg=" .. opt.fg) or "",
    opt.bg and (g .. "bg=" .. opt.bg) or "",
    opt.gui and ((use_tc and "gui=" or "cterm=") .. opt.gui) or "",
    opt.sp and ("guisp=" .. opt.sp) or "",
    opt.blend and ("blend=" .. opt.blend) or ""
  ))
end

---@param from string Syntax group name.
---@param to? string Syntax group name. (default: `"NONE"`)
---@param opt? HiLinkSpec
function M.hi_link(from, to, opt)
  opt = opt or {}
  vim.cmd(string.format(
    "hi%s %s link %s %s",
    opt.force and "!" or "",
    opt.default and "default" or "",
    from,
    to or "NONE"
  ))
end

function M.get_colors()
  return {
    white = M.get_fg("Normal") or "White",
    red = M.get_fg("Keyword") or "Red",
    green = M.get_fg("Character") or "Green",
    yellow = M.get_fg("PreProc") or "Yellow",
    blue = M.get_fg("Include") or "Blue",
    purple = M.get_fg("Define") or "Purple",
    cyan = M.get_fg("Conditional") or "Cyan",
    dark_red = M.get_fg("Keyword") or "DarkRed",
    orange = M.get_fg("Number") or "Orange",
  }
end

function M.get_hl_groups()
  local hl_focused = config.get_config().focused_hl_group
  local reverse = M.get_hl_attr(hl_focused, "reverse") == "1"
  local bg_focused = reverse
    and (M.get_fg({ hl_focused, "Normal" }) or "white")
    or (M.get_bg({ hl_focused, "Normal" }) or "white")
  local fg_focused = reverse and (M.get_bg({ hl_focused, "Normal" }) or "black") or nil

  return {
    Normal = { fg = fg_focused, bg = bg_focused },
    EndOfBuffer = { fg = bg_focused, bg = bg_focused },
    LineNr = { fg = M.get_fg("LineNr"), bg = bg_focused, gui = M.get_gui("LineNr") },
    CursorLineNr = { fg = M.get_fg("CursorLineNr"), bg = bg_focused, gui = M.get_gui("CursorLineNr") },
    SignColumn = { fg = M.get_fg("SignColumn"), bg = bg_focused },
    FoldColumn = { fg = M.get_fg("FoldColumn"), bg = bg_focused },
    WindowPicker = { fg = "#ededed", bg = "#4493c8", ctermfg = 255, ctermbg = 33, gui = "bold" },
  }
end

M.hl_links = {
  LineNrAbove = "WinShiftLineNr",
  LineNrBelow = "WinShiftLineNr",
}

function M.setup()
  for name, opt in pairs(M.get_hl_groups()) do
    M.hi("WinShift" .. name, opt)
  end

  for from, to in pairs(M.hl_links) do
    M.hi_link("WinShift" .. from, to, { default = true })
  end
end

return M

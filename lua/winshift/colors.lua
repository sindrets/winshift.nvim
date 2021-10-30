local config = require("winshift.config")
local api = vim.api
local M = {}

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

---@param group_name string Syntax group name.
---@param trans boolean Translate the syntax group (follows links). True by default.
function M.get_fg(group_name, trans)
  if type(trans) ~= "boolean" then trans = true end
  return M.get_hl_attr(group_name, "fg", trans)
end

---@param group_name string Syntax group name.
---@param trans boolean Translate the syntax group (follows links). True by default.
function M.get_bg(group_name, trans)
  if type(trans) ~= "boolean" then trans = true end
  return M.get_hl_attr(group_name, "bg", trans)
end

---@param group_name string Syntax group name.
---@param trans boolean Translate the syntax group (follows links). True by default.
function M.get_gui(group_name, trans)
  if type(trans) ~= "boolean" then trans = true end
  local hls = {}
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
    if M.get_hl_attr(group_name, attr, trans) == "1" then
      table.insert(hls, attr)
    end
  end

  if #hls > 0 then
    return table.concat(hls, ",")
  end
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
  local focused_bg = M.get_bg(config.get_config().focused_hl_group) or "Visual"

  return {
    Normal = { bg = focused_bg },
    EndOfBuffer = { fg = focused_bg, bg = focused_bg },
    LineNr = { fg = M.get_fg("LineNr"), bg = focused_bg, gui = M.get_gui("LineNr") },
    CursorLineNr = { fg = M.get_fg("CursorLineNr"), bg = focused_bg, gui = M.get_gui("CursorLineNr") },
    SignColumn = { fg = M.get_fg("SignColumn"), bg = focused_bg },
    FoldColumn = { fg = M.get_fg("FoldColumn"), bg = focused_bg },
  }
end

M.hl_links = {
  LineNrAbove = "WinShiftLineNr",
  LineNrBelow = "WinShiftLineNr",
}

function M.setup()
  for name, v in pairs(M.get_hl_groups()) do
    vim.cmd(
      string.format(
        "hi WinShift%s %s %s %s",
        name,
        v.fg and "guifg=" .. v.fg or "",
        v.bg and "guibg=" .. v.bg or "",
        v.gui and "gui=" .. v.gui or ""
      )
    )
  end

  for from, to in pairs(M.hl_links) do
    vim.cmd("hi def link WinShift" .. from .. " " .. to)
  end
end

return M

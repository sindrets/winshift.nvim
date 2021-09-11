local a = vim.api
local M = {}

function M.get_hl_attr(hl_group_name, attr)
  local id = a.nvim_get_hl_id_by_name(hl_group_name)
  if not id then
    return
  end

  local value = vim.fn.synIDattr(id, attr)
  if not value or value == "" then
    return
  end

  return value
end

function M.get_fg(hl_group_name)
  return M.get_hl_attr(hl_group_name, "fg")
end

function M.get_bg(hl_group_name)
  return M.get_hl_attr(hl_group_name, "bg")
end

function M.get_gui(hl_group_name)
  return M.get_hl_attr(hl_group_name, "gui")
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
  return {
    Normal = { bg = M.get_bg("Visual") },
    LineNr = { fg = M.get_fg("LineNr"), bg = M.get_bg("Visual"), gui = M.get_gui("LineNr") },
    CursorLineNr = { fg = M.get_fg("CursorLineNr"), bg = M.get_bg("Visual"), gui = M.get_gui("CursorLineNr") },
    SignColumn = { fg = M.get_fg("SignColumn"), bg = M.get_bg("Visual") },
    FoldColumn = { fg = M.get_fg("FoldColumn"), bg = M.get_bg("Visual") },
  }
end

M.hl_links = {}

function M.setup()
  for name, v in pairs(M.get_hl_groups()) do
    local fg = v.fg and " guifg=" .. v.fg or ""
    local bg = v.bg and " guibg=" .. v.bg or ""
    local gui = v.gui and " gui=" .. v.gui or ""
    vim.cmd("hi def WinShift" .. name .. fg .. bg .. gui)
  end

  for from, to in pairs(M.hl_links) do
    vim.cmd("hi def link WinShift" .. from .. " " .. to)
  end
end

return M

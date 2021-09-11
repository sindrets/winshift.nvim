local utils = require("winshift.utils")
local colors = require("winshift.colors")
local lib = require("winshift.lib")
local api = vim.api
local M = {}

local completion_dir = { "left", "right", "up", "down" }

function M.cmd_winshift(dir)
  if dir then
    if not vim.tbl_contains(completion_dir, dir) then
      utils.err("Direction must be one of: " .. table.concat(completion_dir, ", "))
      return
    end
    lib.move_win(api.nvim_get_current_win(), dir)
  else
    lib.start_move_mode()
  end
end

local function filter_completion(arg_lead, items)
  return vim.tbl_filter(function(item)
    return item:match(utils.pattern_esc(arg_lead))
  end, items)
end

---@diagnostic disable-next-line: unused-local
function M.completion(arg_lead, cmd_line, cur_pos)
  return filter_completion(arg_lead, completion_dir)
end

colors.setup()

return M

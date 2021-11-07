local utils = require("winshift.utils")
local config = require("winshift.config")
local lib = require("winshift.lib")
local api = vim.api
local M = {}

-- Lazily ensure that setup has been run before accessing any module exports.
local init_done = false
local init_safeguard = setmetatable({}, {
  __index = function(_, k)
    if not init_done then
      init_done = true
      if k == "setup" then
        return M[k]
      else
        config.setup({})
        return M[k]
      end
    else
      return M[k]
    end
  end
})

local completion_dir = {
  "left",
  "right",
  "up",
  "down",
  "far_left",
  "far_right",
  "far_up",
  "far_down",
  "swap",
}

function M.setup(user_config)
  config.setup(user_config or {})
end

function M.cmd_winshift(dir)
  if dir then
    if not vim.tbl_contains(completion_dir, dir) then
      utils.err("Action must be one of: " .. table.concat(completion_dir, ", "))
      return
    end
    if dir == "swap" then
      lib.start_swap_mode()
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

return init_safeguard

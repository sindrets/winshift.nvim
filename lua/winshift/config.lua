local utils = require("winshift.utils")
local M = {}

-- stylua: ignore start
M.defaults = {
  highlight_moving_win = true,
  focused_hl_group = "Visual",
  moving_win_options = {
    wrap = false,
    cursorline = false,
    cursorcolumn = false,
    colorcolumn = "",
  },
  keymaps = {
    disable_defaults = false,
    win_move_mode = {
      ["h"] = "left",
      ["j"] = "down",
      ["k"] = "up",
      ["l"] = "right",
      ["H"] = "far_left",
      ["J"] = "far_down",
      ["K"] = "far_up",
      ["L"] = "far_right",
      ["<left>"] = "left",
      ["<down>"] = "down",
      ["<up>"] = "up",
      ["<right>"] = "right",
      ["<S-left>"] = "far_left",
      ["<S-down>"] = "far_down",
      ["<S-up>"] = "far_up",
      ["<S-right>"] = "far_right",
    },
  },
  ---A function that should prompt the user to select a window.
  ---
  ---The window picker is used to select a window while swapping windows with
  ---`:WinShift swap`.
  ---@return integer? winid # Either the selected window ID, or `nil` to
  ---   indicate that the user cancelled / gave an invalid selection.
  window_picker = function()
    return require("winshift.lib").pick_window({
      picker_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
      filter_rules = {
        cur_win = true,
        floats = true,
        filetype = {},
        buftype = {},
        bufname = {},
      },
      ---A function used to filter the list of selectable windows.
      ---@param winids integer[] # The list of selectable window IDs.
      ---@return integer[] filtered # The filtered list of window IDs.
      filter_func = nil,
    })
  end,
}
-- stylua: ignore end

M._config = M.defaults

function M.get_key_dir_map()
  local t = {}

  for lhs, rhs in pairs(M._config.keymaps.win_move_mode) do
    if lhs:match("%b<>") then
      -- Get raw key code for special keys
      lhs = utils.raw_key(lhs)
    end

    t[lhs] = rhs
  end

  return t
end

function M.get_config()
  return M._config
end

function M.setup(user_config)
  user_config = user_config or {}

  M._config = utils.tbl_deep_clone(M.defaults)
  M._config = vim.tbl_deep_extend("force", M._config, user_config)

  M._config.moving_win_options = user_config.moving_win_options or M._config.moving_win_options

  --#region DEPRECATION NOTICES

  if M._config.window_picker_chars or M._config.window_picker_ignore then
    utils.warn(table.concat({
      "'window_picker_chars' and 'window_picker_ignore' has been deprecated!",
      " See ':h winshift.changelog-11' for more information.",
    }, ""))
  end

  --#endregion

  if M._config.keymaps.disable_defaults then
    for name, _ in pairs(M._config.keymaps) do
      if name ~= "disable_defaults" then
        M._config.keymaps[name] = vim.tbl_get(user_config, "keymaps", name) or {}
      end
    end
  end

  require("winshift.colors").setup()
end

return M

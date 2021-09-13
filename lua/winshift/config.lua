local utils = require("winshift.utils")
local M = {}

-- stylua: ignore start
M.defaults = {
  highlight_moving_win = true,
  focused_hl_group = "Visual",
  moving_win_options = {
    wrap = false,
    cursorline = false,
    colorcolumn = "",
  }
}
-- stylua: ignore end

M._config = M.defaults

function M.get_config()
  return M._config
end

function M.setup(user_config)
  user_config = user_config or {}

  M._config = utils.tbl_deep_clone(M.defaults)
  M._config = vim.tbl_deep_extend("force", M._config, user_config)

  M._config.moving_win_options = user_config.moving_win_options or M._config.moving_win_options

  require("winshift.colors").setup()
end

return M

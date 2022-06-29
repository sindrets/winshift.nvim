local utils = require("winshift.utils")
local config = require("winshift.config")
local api = vim.api
local M = {}
local win_option_store = {}

---@class Node : { [integer]: Node }
---@field type '"leaf"'|'"row"'|'"col"'
---@field parent Node
---@field index integer
---@field winid integer|nil

---@class VirtualNode : Node
---@field target Node

---@alias HDirection '"left"'|'"right"'
---@alias VDirection '"up"'|'"down"'
---@alias Direction HDirection|VDirection|'"far_left"'|'"far_right"'|'"far_up"'|'"far_down"'

M.dir_move_map = {
  far_left = "H",
  far_down = "J",
  far_up = "K",
  far_right = "L",
}

function M.process_layout(layout)
  local function recurse(parent)
    ---@type Node
    local node = { type = parent[1] }

    if node.type == "leaf" then
      node.winid = parent[2]
    else
      for i, child in ipairs(parent[2]) do
        node[#node + 1] = recurse(child)
        node[#node].index = i
        node[#node].parent = node
      end
    end

    return node
  end

  return recurse(layout)
end

function M.get_layout_tree()
  return M.process_layout(vim.fn.winlayout())
end

---@param node Node
---@return Node
function M.get_first_leaf(node)
  local cur = node
  while cur.type ~= "leaf" do
    cur = cur[1]
  end
  return cur
end

---@param node Node
---@return Node
function M.get_last_leaf(node)
  local cur = node
  while cur.type ~= "leaf" do
    cur = cur[#cur]
  end
  return cur
end

---@param tree Node
---@param winid integer
function M.find_leaf(tree, winid)
  ---@param node Node
  ---@return Node
  local function recurse(node)
    if node.type == "leaf" and node.winid == winid then
      return node
    else
      for _, child in ipairs(node) do
        local target = recurse(child)
        if target then
          return target
        end
      end
    end
  end

  return recurse(tree)
end

---@param a Node
---@param b Node
function M.swap_leaves(a, b)
  vim.cmd(
    string.format(
      "noautocmd keepjumps %dwindo belowright %s",
      api.nvim_win_get_number(a.winid),
      a.parent.type == "col" and "vsp" or "sp"
    )
  )
  local temp_a = api.nvim_get_current_win()
  local opt_a = { vertical = a.parent.type == "col", rightbelow = false }

  vim.cmd(
    string.format(
      "noautocmd keepjumps %dwindo belowright %s",
      api.nvim_win_get_number(b.winid),
      b.parent.type == "col" and "vsp" or "sp"
    )
  )
  local temp_b = api.nvim_get_current_win()
  local opt_b = { vertical = b.parent.type == "col", rightbelow = false }

  vim.fn.win_splitmove(a.winid, temp_b, opt_b)
  vim.fn.win_splitmove(b.winid, temp_a, opt_a)
  api.nvim_win_close(temp_a, true)
  api.nvim_win_close(temp_b, true)
end

---Move a row into a target window, replacing the target.
---@param row Node
---@param target integer Window id
---@param ignore? table<integer, boolean>
function M.move_row(row, target, ignore)
  ignore = ignore or {}
  local opt = { vertical = true, rightbelow = false }

  ---@type Node
  for _, node in ipairs(row) do
    if node.type == "col" then
      local nr = api.nvim_win_get_number(target)
      vim.cmd("noautocmd keepjumps " .. nr .. "windo aboveleft vsp")
      M.move_col(node, api.nvim_get_current_win(), ignore)
    elseif not ignore[node.winid] then
      vim.fn.win_splitmove(node.winid, target, opt)
    end
  end

  api.nvim_win_close(target, true)
end

---Move a column into a target window, replacing the target.
---@param col Node
---@param target integer Window id
---@param ignore? table<integer, boolean>
function M.move_col(col, target, ignore)
  ignore = ignore or {}
  local opt = { vertical = false, rightbelow = false }

  ---@type Node
  for _, node in ipairs(col) do
    if node.type == "row" then
      local nr = api.nvim_win_get_number(target)
      vim.cmd("noautocmd keepjumps " .. nr .. "windo aboveleft sp")
      M.move_row(node, api.nvim_get_current_win(), ignore)
    elseif not ignore[node.winid] then
      vim.fn.win_splitmove(node.winid, target, opt)
    end
  end

  api.nvim_win_close(target, true)
end

---Move a leaf out of a row in a given direction.
---@param leaf Node
---@param row Node
---@param dir VDirection
function M.row_move_out(leaf, row, dir)
  vim.cmd(
    string.format(
      "noautocmd keepjumps %dwindo %s sp",
      api.nvim_win_get_number(leaf.winid),
      dir == "up" and "belowright" or "aboveleft"
    )
  )
  local tempwin = api.nvim_get_current_win()
  M.move_row(row, tempwin, { [leaf.winid] = true })
end

---Move a leaf out of a column in a given direction.
---@param leaf Node
---@param col Node
---@param dir HDirection
function M.col_move_out(leaf, col, dir)
  vim.cmd(
    string.format(
      "noautocmd keepjumps %dwindo %s vsp",
      api.nvim_win_get_number(leaf.winid),
      dir == "left" and "belowright" or "aboveleft"
    )
  )
  local tempwin = api.nvim_get_current_win()
  M.move_col(col, tempwin, { [leaf.winid] = true })
end

---Move a leaf into a row.
---@param leaf Node
---@param row Node
---@param dir HDirection Determines what side of the row the leaf is moved to.
function M.row_move_in(leaf, row, dir)
  local target_leaf = dir == "right" and M.get_last_leaf(row) or M.get_first_leaf(row)
  local opt = { vertical = true, rightbelow = dir == "right" }
  vim.fn.win_splitmove(leaf.winid, target_leaf.winid, opt)

  vim.cmd(
    string.format(
      "noautocmd keepjumps %dwindo %s vsp",
      api.nvim_win_get_number(leaf.winid),
      dir == "right" and "aboveleft" or "belowright"
    )
  )
  local tempwin = api.nvim_get_current_win()
  M.move_row(row, tempwin)
end

---Move a leaf into a column.
---@param leaf Node
---@param col Node
---@param dir VDirection Determines what side of the col the leaf is moved to.
function M.col_move_in(leaf, col, dir)
  local target_leaf = dir == "down" and M.get_last_leaf(col) or M.get_first_leaf(col)
  local opt = { vertical = false, rightbelow = dir == "down" }
  vim.fn.win_splitmove(leaf.winid, target_leaf.winid, opt)

  vim.cmd(
    string.format(
      "noautocmd keepjumps %dwindo %s sp",
      api.nvim_win_get_number(leaf.winid),
      dir == "down" and "aboveleft" or "belowright"
    )
  )
  local tempwin = api.nvim_get_current_win()
  M.move_col(col, tempwin)
end

---Get the next node in a given direction in the given leaf's closest row
---parent. Returns `nil` if there's no node in the given direction.
---@param leaf Node
---@param dir HDirection
---@return Node|nil
function M.next_node_horizontal(leaf, dir)
  local outside_parent = (dir == "left" and leaf.index == 1)
    or (dir == "right" and leaf.index == #leaf.parent)

  if leaf.parent.type == "col" or outside_parent then
    local outer_parent = leaf.parent.parent
    if not outer_parent or outer_parent.type == "col" then
      return
    end

    return outer_parent[leaf.parent.index + ((dir == "left" and -1) or 1)]
  else
    return leaf.parent[leaf.index + ((dir == "left" and -1) or 1)]
  end
end

---Get the next node in a given direction in the given leaf's closest column
---parent. Returns `nil` if there's no node in the given direction.
---@param leaf Node
---@param dir VDirection
---@return Node|nil
function M.next_node_vertical(leaf, dir)
  local outside_parent = (dir == "up" and leaf.index == 1)
    or (dir == "down" and leaf.index == #leaf.parent)

  if leaf.parent.type == "row" or outside_parent then
    local outer_parent = leaf.parent.parent
    if not outer_parent or outer_parent.type == "row" then
      return
    end

    return outer_parent[leaf.parent.index + ((dir == "up" and -1) or 1)]
  else
    return leaf.parent[leaf.index + ((dir == "up" and -1) or 1)]
  end
end

---@class WindowPickerFilterRules
---@field cur_win boolean
---@field floats boolean
---@field filetype string[]
---@field buftype string[]
---@field bufname string[]

---@class WindowPickerSpec
---@field picker_chars string
---@field filter_rules WindowPickerFilterRules
---@field filter_func fun(winids: integer[]): integer[]

---Get user to pick a window. Selectable windows are all windows in the current
---tabpage.
---@param opt? WindowPickerSpec
---@return integer|nil -- If a valid window was picked, return its id. If an
---       invalid window was picked / user canceled, return nil. If there are
---       no selectable windows, return -1.
function M.pick_window(opt)
  opt = opt or {}
  local tabpage = api.nvim_get_current_tabpage()
  local win_ids = api.nvim_tabpage_list_wins(tabpage)
  local curwin = api.nvim_get_current_win()
  local filter_rules = opt.filter_rules or {}

  local selectable = vim.tbl_filter(function (id)
    if filter_rules.cur_win and curwin == id then
      return false
    elseif filter_rules.floats and api.nvim_win_get_config(id).relative ~= "" then
      return false
    end

    local bufid = api.nvim_win_get_buf(id)
    local bufname = api.nvim_buf_get_name(bufid)

    for _, option in ipairs({ "filetype", "buftype" }) do
      if vim.tbl_contains(filter_rules[option] or {}, vim.bo[bufid][option]) then
        return false
      end
    end

    for _, pattern in ipairs(filter_rules.bufname or {}) do
      local regex = vim.regex(pattern)
      if regex:match_str(bufname) ~= nil then
        return false
      end
    end

    return true
  end, win_ids)

  if opt.filter_func then
    selectable = opt.filter_func(selectable)
  end

  -- If there are no selectable windows: return. If there's only 1, return it without picking.
  if #selectable == 0 then return -1 end
  if #selectable == 1 then return selectable[1] end

  local chars = (opt.picker_chars or "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"):upper()
  local i = 1
  local win_opts = {}
  local win_map = {}
  local laststatus = vim.o.laststatus
  vim.o.laststatus = 2

  -- Setup UI
  for _, id in ipairs(selectable) do
    local char = chars:sub(i, i)

    win_map[char] = id
    win_opts[id] = {
      statusline = vim.wo[id].statusline,
      winhl = vim.wo[id].winhl,
    }

    utils.set_local(id, {
      statusline = "%=" .. char .. "%=",
      winhl = {
        "StatusLine:WinShiftWindowPicker,StatusLineNC:WinShiftWindowPicker",
        opt = { method = "append" },
      },
    })

    i = i + 1
    if i > #chars then break end
  end

  vim.cmd("redraw")
  local ok, resp = pcall(utils.input_char, "Pick window: ", { prompt_hl = "ModeMsg" })
  if not ok then
    utils.clear_prompt()
  end
  resp = (resp or ""):upper()

  -- Restore window options
  for _, id in ipairs(selectable) do
    utils.set_local(id, win_opts[id])
  end

  vim.o.laststatus = laststatus

  return win_map[resp]
end

---@param leaf Node
---@param flatten? boolean
---@return VirtualNode|nil
function M.create_virtual_set(leaf, flatten)
  if not leaf.parent then
    return
  end

  local parent = leaf.parent

  -- Handle case where moving the leaf will result in a different virtual set.
  if flatten
      and #parent == 2
      and parent[leaf.index % 2 + 1].type == "leaf"
      and parent.parent then
    leaf = utils.tbl_clone(leaf)
    parent = utils.tbl_clone(parent.parent)
    parent[leaf.parent.index] = leaf
    table.insert(parent, leaf.parent.index, utils.tbl_clone(leaf.parent[leaf.index % 2 + 1]))

    for i, l in ipairs(parent) do
      l.index = i
      l.parent = parent
    end
  end

  local first, last = leaf.index, leaf.index

  for i = leaf.index - 1, 1, -1 do
    if parent[i].type ~= "leaf" then
      break
    end
    first = i
  end

  for i = leaf.index + 1, #parent do
    if parent[i].type ~= "leaf" then
      break
    end
    last = i
  end

  if (first == leaf.index and last == leaf.index) -- Virtual set is empty
      or (first == 1 and last == #parent)         -- Virtual set is the same as the normal set
      or last - first + 1 == 2 then               -- Virtual sets of 2 leaves are pointless
    return
  end

  local target = utils.tbl_clone(leaf)
  local set = { target = target }
  for k, v in pairs(parent) do
    if type(k) ~= "number" then
      set[k] = v
    end
  end
  for i = first, last do
    set[#set + 1] = parent[i]
  end
  set.parent = parent.parent
  target.parent = set
  return set
end

---@param winid integer
---@param dir Direction
function M.move_win(winid, dir)
  if M.dir_move_map[dir] then
    vim.cmd(string.format("%dwincmd %s", api.nvim_win_get_number(winid), M.dir_move_map[dir]))
    return
  end

  local tree = M.get_layout_tree()
  local target_leaf = M.find_leaf(tree, winid)
  local outer_parent = (target_leaf.parent and target_leaf.parent.parent) or {}

  -- If the target leaf has no parent, there is only one window in the layout.
  if target_leaf and target_leaf.parent then
    local ok, err = utils.no_win_event_call(function()
      if dir == "left" or dir == "right" then
        -- Horizontal
        if target_leaf.parent.type == "col" then
          local set = M.create_virtual_set(target_leaf)
          target_leaf = (set and set.target) or target_leaf
          M.col_move_out(target_leaf, target_leaf.parent, dir)
        else
          local next_node = M.next_node_horizontal(target_leaf, dir)
          local set = M.create_virtual_set(target_leaf, true)

          if next_node then
            if
              target_leaf.parent.type == "row"
              and #target_leaf.parent == 2
              and target_leaf.parent[1].type == "leaf"
              and target_leaf.parent[2].type == "leaf"
            then
              -- Swap the windows
              M.swap_leaves(target_leaf.parent[1], target_leaf.parent[2])
            else
              M.col_move_in(target_leaf, next_node, dir)
            end
          elseif set and set.type == "col" then
            M.col_move_out(set.target, set, dir)
          elseif outer_parent.type == "col" then
            M.col_move_out(target_leaf, outer_parent, dir)
          end
        end
      else
        -- Vertical
        if target_leaf.parent.type == "row" then
          local set = M.create_virtual_set(target_leaf)
          target_leaf = (set and set.target) or target_leaf
          M.row_move_out(target_leaf, target_leaf.parent, dir)
        else
          local next_node = M.next_node_vertical(target_leaf, dir)
          local set = M.create_virtual_set(target_leaf, true)

          if next_node then
            if
              target_leaf.parent.type == "col"
              and #target_leaf.parent == 2
              and target_leaf.parent[1].type == "leaf"
              and target_leaf.parent[2].type == "leaf"
            then
              -- Swap the windows
              M.swap_leaves(target_leaf.parent[1], target_leaf.parent[2])
            else
              M.row_move_in(target_leaf, next_node, dir)
            end
          elseif set and set.type == "row" then
            M.row_move_out(set.target, set, dir)
          elseif outer_parent.type == "row" then
            M.row_move_out(target_leaf, outer_parent, dir)
          end
        end
      end
    end)

    api.nvim_set_current_win(winid)
    if not ok then
      utils.err(err)
      utils.err(debug.traceback())
    end
  end
end

function M.start_move_mode()
  local char, raw
  local esc = utils.raw_key("<esc>")
  local cur_win = api.nvim_get_current_win()
  local lasthl = vim.wo[cur_win].winhl
  local conf = config.get_config()
  local key_dir_map = config.get_key_dir_map()
  M.save_win_options(cur_win)

  if conf.highlight_moving_win then
    M.highlight_win(cur_win)
  end
  utils.set_local(cur_win, conf.moving_win_options)
  vim.cmd("redraw")

  local ok, err = pcall(function()
    while not (char == "q" or raw == esc) do
      api.nvim_echo({ { "-- WIN MOVE MODE -- press 'q' to exit", "ModeMsg" } }, false, {})
      char, raw = utils.input_char(nil, { clear_prompt = false, allow_non_ascii = true })
      local dir = key_dir_map[char or raw]
      if dir then
        M.move_win(cur_win, dir)
      end
      vim.cmd("redraw")
    end
  end)

  utils.clear_prompt()

  if conf.highlight_moving_win then
    vim.wo[cur_win].winhl = lasthl
  end

  M.restore_win_options(cur_win)

  if not ok then
    utils._echo_multiline(err, "ErrorMsg")
  end
end

function M.start_swap_mode()
  local cur_win = api.nvim_get_current_win()
  local lasthl = vim.wo[cur_win].winhl
  local conf = config.get_config()
  M.save_win_options(cur_win)

  if conf.highlight_moving_win then
    M.highlight_win(cur_win)
  end
  utils.set_local(cur_win, conf.moving_win_options)
  vim.cmd("redraw")

  local ok, err = pcall(function()
    local target = conf.window_picker()

    if target == -1 or target == nil then
      return
    end

    local tree = M.get_layout_tree()
    local cur_leaf = M.find_leaf(tree, cur_win)
    local target_leaf = M.find_leaf(tree, target)
    M.swap_leaves(cur_leaf, target_leaf)
  end)

  if conf.highlight_moving_win then
    vim.wo[cur_win].winhl = lasthl
  end

  M.restore_win_options(cur_win)

  if not ok then
    utils._echo_multiline(err, "ErrorMsg")
  end
end

function M.save_win_options(winid)
  win_option_store[winid] = {}
  local last_winid = api.nvim_get_current_win()
  utils.no_win_event_call(function()
    api.nvim_set_current_win(winid)
    for option, _ in pairs(config.get_config().moving_win_options) do
      local value = vim.opt_local[option]._value
      if value ~= "" then
        win_option_store[winid][option] = value
      end
    end
  end)
  api.nvim_set_current_win(last_winid)
end

function M.restore_win_options(winid)
  for option, _ in pairs(config.get_config().moving_win_options) do
    if win_option_store[winid][option] then
      utils.set_local(winid, { [option] = win_option_store[winid][option] })
    else
      utils.unset_local(winid, option)
    end
  end
end

function M.highlight_win(winid)
  local curhl = vim.wo[winid].winhl
  local hl = {
    "Normal:WinShiftNormal",
    "EndOfBuffer:WinShiftEndOfBuffer",
    "LineNr:WinShiftLineNr",
    "CursorLineNr:WinShiftCursorLineNr",
    "SignColumn:WinShiftSignColumn",
    "FoldColumn:WinShiftFoldColumn",
    curhl ~= "" and curhl or nil,
  }

  if vim.fn.has("nvim-0.6") == 1 then
    hl = utils.vec_join(
      hl,
      {
        "LineNrAbove:WinShiftLineNrAbove",
        "LineNrBelow:WinShiftLineNrBelow",
      }
    )
  end

  vim.wo[winid].winhl = table.concat(hl, ",")
end

return M

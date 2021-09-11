local utils = require("winshift.utils")
local api = vim.api
local M = {}

---@class Node
---@type table<integer, Node>
---@field type '"leaf"'|'"row"'|'"col"'
---@field parent Node
---@field index integer
---@field bufid integer
---@field winid integer|nil

---@class VirtualNode
---@type table<integer, Node>
---@field type '"leaf"'|'"row"'|'"col"'
---@field target Node
---@field parent Node
---@field index integer
---@field bufid integer
---@field winid integer|nil

M.key_dir_map = {
  h = "left",
  j = "down",
  k = "up",
  l = "right",
  [utils.raw_key("<left>")] = "left",
  [utils.raw_key("<down>")] = "down",
  [utils.raw_key("<up>")] = "up",
  [utils.raw_key("<right>")] = "right",
}

function M.process_layout(layout)
  local function recurse(parent)
    ---@type Node
    local node = { type = parent[1] }

    if node.type == "leaf" then
      node.winid = parent[2]
      node.bufid = api.nvim_win_get_buf(node.winid)
    else
      for i, child in ipairs(parent[2]) do
        node[#node+1] = recurse(child)
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
  vim.cmd(string.format(
    "noautocmd keepjumps %dwindo belowright %s",
    api.nvim_win_get_number(a.winid),
    a.parent.type == "col" and "vsp" or "sp"
  ))
  local temp_a = api.nvim_get_current_win()
  local opt_a = { vertical = a.parent.type == "col", rightbelow = false }

  vim.cmd(string.format(
    "noautocmd keepjumps %dwindo belowright %s",
    api.nvim_win_get_number(b.winid),
    b.parent.type == "col" and "vsp" or "sp"
  ))
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
---@param ignore table<integer, boolean>
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
---@param ignore table<integer, boolean>
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
---@param dir '"up"'|'"down"'
function M.row_move_out(leaf, row, dir)
  vim.cmd(string.format(
    "noautocmd keepjumps %dwindo %s sp",
    api.nvim_win_get_number(leaf.winid),
    dir == "up" and "belowright" or "aboveleft"
  ))
  local tempwin = api.nvim_get_current_win()
  M.move_row(row, tempwin, { [leaf.winid] = true })
end

---Move a leaf out of a column in a given direction.
---@param leaf Node
---@param col Node
---@param dir '"left"'|'"right"'
function M.col_move_out(leaf, col, dir)
  vim.cmd(string.format(
    "noautocmd keepjumps %dwindo %s vsp",
    api.nvim_win_get_number(leaf.winid),
    dir == "left" and "belowright" or "aboveleft"
  ))
  local tempwin = api.nvim_get_current_win()
  M.move_col(col, tempwin, { [leaf.winid] = true })
end

---Move a leaf into a row.
---@param leaf Node
---@param row Node
---@param dir '"left"'|'"right"'
function M.row_move_in(leaf, row, dir)
  local target_leaf = dir == "left" and M.get_last_leaf(row) or M.get_first_leaf(row)
  local opt = { vertical = true, rightbelow = dir == "left" }
  vim.fn.win_splitmove(leaf.winid, target_leaf.winid, opt)

  vim.cmd(string.format(
    "noautocmd keepjumps %s %dwindo vsp",
    dir == "left" and "aboveleft" or "belowright",
    api.nvim_win_get_number(leaf.winid)
  ))
  local tempwin = api.nvim_get_current_win()
  M.move_row(row, tempwin)
end

---Move a leaf into a column.
---@param leaf Node
---@param col Node
---@param dir '"up"'|'"down"'
function M.col_move_in(leaf, col, dir)
  local target_leaf = dir == "up" and M.get_last_leaf(col) or M.get_first_leaf(col)
  local opt = { vertical = false, rightbelow = dir == "up" }
  vim.fn.win_splitmove(leaf.winid, target_leaf.winid, opt)

  vim.cmd(string.format(
    "noautocmd keepjumps %s %dwindo sp",
    dir == "up" and "aboveleft" or "belowright",
    api.nvim_win_get_number(leaf.winid)
  ))
  local tempwin = api.nvim_get_current_win()
  M.move_col(col, tempwin)
end

---Get the next node in a given direction in the given leaf's closest row
---parent. Returns `nil` if there's no node in the given direction.
---@param leaf Node
---@param dir '"left"'|'"right"'
---@return Node|nil
function M.next_node_horizontal(leaf, dir)
  local outside_parent = (
    (dir == "left" and leaf.index == 1)
    or (dir == "right" and leaf.index == #leaf.parent)
  )

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
---@param dir '"up"'|'"down"'
---@return Node|nil
function M.next_node_vertical(leaf, dir)
  local outside_parent = (
    (dir == "up" and leaf.index == 1)
    or (dir == "down" and leaf.index == #leaf.parent)
  )

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

---@param leaf Node
---@return VirtualNode|nil
function M.create_virtual_set(leaf)
  if not leaf.parent then
    return
  end

  local first, last = leaf.index, leaf.index

  for i = leaf.index - 1, 1, -1 do
    if leaf.parent[i].type ~= "leaf" then
      goto done_first
    end
    first = i
  end
  ::done_first::

  for i = leaf.index + 1, #leaf.parent do
    if leaf.parent[i].type ~= "leaf" then
      goto done_last
    end
    last = i
  end
  ::done_last::

  if not (first == leaf.index and last == leaf.index) then
    local target = utils.tbl_clone(leaf)
    local set = { target = target }
    for k, v in pairs(leaf.parent) do
      if type(k) ~= "number" then
        set[k] = v
      end
    end
    for i = first, last do
      set[i - first + 1] = leaf.parent[i]
    end
    set.parent = leaf.parent.parent
    target.parent = set
    return set
  end
end

---@param winid integer
---@param dir '"left"'|'"right"'|'"up"'|'"down"'
function M.move_win(winid, dir)
  local tree = M.get_layout_tree()
  local target_leaf = M.find_leaf(tree, winid)
  local outer_parent = (target_leaf.parent and target_leaf.parent.parent) or {}

  -- If the target leaf has no parent, there is only one window in the layout.
  if target_leaf and target_leaf.parent then
    vim.opt.eventignore = "WinEnter,WinLeave,WinNew,WinClosed,BufEnter,BufLeave"

    local ok, err = pcall(function()
      if dir == "left" or dir == "right" then
        -- Horizontal
        local set
        if target_leaf.parent.type == "col" then
          set = M.create_virtual_set(target_leaf)
          -- print("hori set:", vim.inspect(set))
        end

        if set or target_leaf.parent.type == "col" then
          -- print("col move out 1")
          target_leaf = (set and set.target) or target_leaf
          M.col_move_out(target_leaf, target_leaf.parent, dir)
        else
          local next_node = M.next_node_horizontal(target_leaf, dir)
          if next_node then
            if (
              target_leaf.parent.type == "row"
              and #target_leaf.parent == 2
              and #outer_parent > 1
              and target_leaf.parent[1].type == "leaf"
              and target_leaf.parent[2].type == "leaf"
              ) then
              -- Swap the windows
              M.swap_leaves(target_leaf.parent[1], target_leaf.parent[2])
            else
              -- print(vim.inspect(next_node, {depth = 2}))
              M.col_move_in(target_leaf, next_node, dir)
            end
          elseif outer_parent.type == "col" then
            -- print("col move out 2")
            M.col_move_out(target_leaf, outer_parent, dir)
          end
        end
      else
        -- Vertical
        local set
        if target_leaf.parent.type == "row" then
          set = M.create_virtual_set(target_leaf)
          -- print("vert set:", vim.inspect(set))
        end

        if set or target_leaf.parent.type == "row" then
          target_leaf = (set and set.target) or target_leaf
          M.row_move_out(target_leaf, target_leaf.parent, dir)
        else
          local next_node = M.next_node_vertical(target_leaf, dir)
          if next_node then
            if (
              target_leaf.parent.type == "col"
              and #target_leaf.parent == 2
              and #outer_parent > 1
              and target_leaf.parent[1].type == "leaf"
              and target_leaf.parent[2].type == "leaf"
              ) then
              M.swap_leaves(target_leaf.parent[1], target_leaf.parent[2])
            else
            M.row_move_in(target_leaf, next_node, dir)
            end
          elseif outer_parent.type == "row" then
            M.row_move_out(target_leaf, outer_parent, dir)
          end
        end
      end
    end)

    vim.opt.eventignore = ""
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

  while not (char == "q" or raw == esc) do
    api.nvim_echo({{ "-- WIN MOVE MODE -- press 'q' to exit", "ModeMsg" }}, false, {})
    char, raw = utils.input_char(nil, true)
    local dir = M.key_dir_map[char or raw]
    if dir then
      M.move_win(cur_win, dir)
      vim.cmd("redraw")
    end
  end
end

_G.WinShift = M
return M

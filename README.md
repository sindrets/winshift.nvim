# WinShift.nvim

> Rearrange your windows with ease.

![showcase](https://user-images.githubusercontent.com/2786478/133154376-539474eb-73c9-4cd7-af8c-a6abb037c061.gif)

## Introduction

Window moving in vim is rather limited. You can exchange a window with any other
window in the same column or row, and you can rotate the order of windows within
a column or row. This doesn't grant much flexibility, and yet there are
limitations to when these operations work.

WinShift lets you freely rearrange your window layouts by letting you move any
window in any direction. Further, it doesn't only let you move around windows,
but also lets you form new columns and rows by moving into windows horizontally
or vertically respectively.

## Requirements

- Neovim ≥ 0.5.0

## Installation

Install the plugin with your package manager of choice.

```vim
" Plug
Plug 'sindrets/winshift.nvim'
```

```lua
-- Packer
use 'sindrets/winshift.nvim'
```

## Configuration

```lua
-- Lua
require("winshift").setup({
  highlight_moving_win = true,  -- Highlight the window being moved
  focused_hl_group = "Visual",  -- The highlight group used for the moving window
  moving_win_options = {
    -- These are local options applied to the moving window while it's
    -- being moved. They are unset when you leave Win-Move mode.
    wrap = false,
    cursorline = false,
    cursorcolumn = false,
    colorcolumn = "",
  },
  keymaps = {
    disable_defaults = false, -- Disable the default keymaps
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
      -- A string of chars used as identifiers by the window picker.
      picker_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
      filter_rules = {
        -- This table allows you to indicate to the window picker that a window
        -- should be ignored if its buffer matches any of the following criteria.
        cur_win = true, -- Filter out the current window
        floats = true,  -- Filter out floating windows
        filetype = {},  -- List of ignored file types
        buftype = {},   -- List of ignored buftypes
        bufname = {},   -- List of vim regex patterns matching ignored buffer names
      },
      ---A function used to filter the list of selectable windows.
      ---@param winids integer[] # The list of selectable window IDs.
      ---@return integer[] filtered # The filtered list of window IDs.
      filter_func = nil,
    })
  end,
})
```

Optionally create some mappings for starting Win-Move mode:

```vim
" Start Win-Move mode:
nnoremap <C-W><C-M> <Cmd>WinShift<CR>
nnoremap <C-W>m <Cmd>WinShift<CR>

" Swap two windows:
nnoremap <C-W>X <Cmd>WinShift swap<CR>

" If you don't want to use Win-Move mode you can create mappings for calling the
" move commands directly:
nnoremap <C-M-H> <Cmd>WinShift left<CR>
nnoremap <C-M-J> <Cmd>WinShift down<CR>
nnoremap <C-M-K> <Cmd>WinShift up<CR>
nnoremap <C-M-L> <Cmd>WinShift right<CR>
```

## Usage

### `:WinShift [direction]`

When called without `[direction]`: starts Win-Move mode targeting the current
window for moving. You can then move the window either by using `hjkl` or the
arrow keys. You can move the window to any of the far ends of the viewport by
pressing one of `HJKL`, or <kbd>shift</kbd> + any arrow key. Exit Win-Move mode
by pressing `q` / `<esc>` / `<C-c>`.

With `[direction]`: perform a one-shot move operation on the current window,
moving it in the given direction. `[direction]` can be one of:

- `left`, `right`, `up`, `down`, `far_left`, `far_right`, `far_up`, `far_down`

The `far_` variants will move the window to the far
end of the viewport in the given direction.

### `:WinShift swap`

Swap the current window with another. When this command is called, you'll be
prompted to select the window you want to swap with. A selection is made by
pressing the character displayed in the statusline of the target window. The
input is case-insensitive.

## Caveats

Moving through windows with `'winfixwidth'` and / or `'winfixheight'` can be a
bit wonky. It will work, but it can be a bit hard to follow the movement, and
the fixed window might end up with different dimensions after. This is simply a
consequence of vim being forced to resize the window due to there not being
enough space to adhere to the fixed window's preferred dimensions.

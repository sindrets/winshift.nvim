# Winshift.nvim

> Rearrange your windows with ease.

![showcase](https://user-images.githubusercontent.com/2786478/133154376-539474eb-73c9-4cd7-af8c-a6abb037c061.gif)

## Introduction

Window moving in vim is rather limited. You can exchange a window with any other
window in the same column or row, and you can rotate the order of windows within
a column or row. This doesn't grant much flexibility, and yet there are
limitations to when these operations work.

Winshift lets you freely rearrange your window layouts by letting you move any
window in any direction. Further, it doesn't only let you move around windows,
but also lets you form new columns and rows by moving into windows horizontally
or vertically respectively.

## Requirements

- Neovim >=0.5.0

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
  }
})
```

Optionally create some mappings for starting Win-Move mode:

```vim
" Start Win-Move mode:
nnoremap <C-W><C-M> <Cmd>Winshift<CR>
nnoremap <C-W>m <Cmd>Winshift<CR>

" If you don't want to use Win-Move mode you can create mappings for calling the
" move commands directly:
nnoremap <C-M-H> <Cmd>Winshift left<CR>
nnoremap <C-M-J> <Cmd>Winshift down<CR>
nnoremap <C-M-K> <Cmd>Winshift up<CR>
nnoremap <C-M-L> <Cmd>Winshift right<CR>
```

## Usage

### `:Winshift [direction]`

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

## Caveats

Moving through windows with `'winfixwidth'` and / or `'winfixheight'` can be a
bit wonky. It will work, but it can be a bit hard to follow the movement, and
the fixed window might end up with different dimensions after. This is simply a
consequence of vim being forced to resize the window due to there not being
enough space to adhere to the fixed window's preferred dimensions.

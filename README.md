# Winshift.nvim

> Rearrange your windows with ease.

![showcase](https://user-images.githubusercontent.com/2786478/133154376-539474eb-73c9-4cd7-af8c-a6abb037c061.gif)

## Introduction

Winshift lets you move windows, not only around each other, but also in and out
of rows and columns.

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

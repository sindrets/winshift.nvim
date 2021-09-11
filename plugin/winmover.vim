if !has('nvim-0.5') || exists('g:winmover_nvim_loaded') | finish | endif

command! WinMoveMode lua require("winmover").start_move_mode()

nnoremap <silent> <C-W><C-M> <Cmd>WinMoveMode<CR>
nnoremap <silent> <C-W>m <Cmd>WinMoveMode<CR>

let g:winmover_nvim_loaded = 1

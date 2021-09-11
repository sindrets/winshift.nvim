if !has('nvim-0.5') || exists('g:winshift_nvim_loaded') | finish | endif

command! WinShift lua require("winshift").start_move_mode()

nnoremap <silent> <C-W><C-M> <Cmd>WinShift<CR>
nnoremap <silent> <C-W>m <Cmd>WinShift<CR>

augroup WinShift
    au!
    au ColorScheme * lua require("winshift.colors").setup()
augroup END

let g:winshift_nvim_loaded = 1

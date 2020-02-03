
let g:loaded_mrw = 1

command! -nargs=0   MRW     :call mrw#exec()

augroup mrw
    autocmd!
    autocmd BufWritePost * :call mrw#bufwritepost()
augroup END


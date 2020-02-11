
let g:loaded_mrw = 1

command! -nargs=? -complete=customlist,mrw#comp   MRW     :call mrw#exec(<q-args>)

augroup mrw
    autocmd!
    autocmd BufWritePost * :call mrw#bufwritepost()
augroup END



let g:loaded_mrw = 1

command! -nargs=? -complete=customlist,mrw#comp   MRW     :call mrw#exec(<q-args>)

augroup mrw
    autocmd!
	autocmd BufWritePost * :call mrw#bufwritepost()
	autocmd FileType   mrw :nnoremap <buffer><cr>    <Cmd>call mrw#select()<cr>
	autocmd FileType   mrw :nnoremap <buffer><space> <Cmd>call mrw#select()<cr>
augroup END


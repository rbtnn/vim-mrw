
let g:loaded_mrw = 1

let g:mrw_limit = get(g:, 'mrw_limit', 300)
let g:mrw_cache_path = expand(get(g:, 'mrw_cache_path', '~/.mrw'))

command! -nargs=? -complete=customlist,mrw#comp   MRW     :call mrw#exec(<q-args>)

augroup mrw
    autocmd!
	autocmd BufWritePost * :call mrw#bufwritepost()
	autocmd FileType   mrw :nnoremap <buffer><cr>    :<C-u>call mrw#select()<cr>
	autocmd FileType   mrw :nnoremap <buffer><space> :<C-u>call mrw#select()<cr>
augroup END


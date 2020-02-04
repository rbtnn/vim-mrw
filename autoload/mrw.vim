
function! s:fullpath(path) abort
    return fnamemodify(resolve(a:path), ':p:gs?\\?/?')
endfunction

let s:mrw_cache_path = s:fullpath(expand('<sfile>:h:h') .. '/.mrw.' .. hostname())
let s:mrw_limit = 100
let s:mrw_title = 'mrw'
let s:mrw_delimiter = ' | '
let s:mrw_defaultopt = {
    \   'title' : s:mrw_title,
    \   'pos' : 'center',
    \   'padding' : [1,3,1,3],
    \ }

function! mrw#exec() abort
    let xs = mrw#read_cachefile(expand('%'))
    let tstatus = term_getstatus(bufnr())
    if (tstatus != 'finished') && !empty(tstatus)
        call popup_notification('could not open on running terminal buffer', s:mrw_defaultopt)
    elseif !empty(getcmdwintype())
        call popup_notification('could not open on command-line window', s:mrw_defaultopt)
    elseif &modified
        call popup_notification('could not open on modified buffer', s:mrw_defaultopt)
    elseif empty(xs)
        call popup_notification('no most recently written', s:mrw_defaultopt)
    else
        " calcate the width of second column
        let fname_max = 0
        for x in xs
            let fname = fnamemodify(x, ':t')
            if fname_max < strdisplaywidth(fname)
                let fname_max = strdisplaywidth(fname)
            endif
        endfor

        " make lines
        let lines = []
        for x in sort(xs, { i1,i2 -> getftime(i2) - getftime(i1) })
            let fname = fnamemodify(x, ':t')
            let dir = fnamemodify(x, ':h')
            let lines += [join([
                \ strftime('%c', getftime(x)),
                \ s:padding_right_space(fname, fname_max),
                \ dir,
                \ ], s:mrw_delimiter)]
        endfor

        call popup_menu(lines, extend(deepcopy(s:mrw_defaultopt), {
            \   'title' : s:mrw_title,
            \   'close' : 'button',
            \   'maxwidth' : &columns * 2 / 3,
            \   'maxheight' : &lines * 2 / 3,
            \   'callback' : function('s:mrw_callback'),
            \ }))
    endif
endfunction

function! mrw#bufwritepost() abort
    let path = expand('<afile>')
    if filereadable(path)
        call writefile([(s:fullpath(path))] + mrw#read_cachefile(path), s:mrw_cache_path)
    endif
endfunction

function! mrw#read_cachefile(curr_file) abort
    if filereadable(s:mrw_cache_path)
        let path = s:fullpath(a:curr_file)
        return filter(readfile(s:mrw_cache_path), { i,x -> (x != path) && filereadable(x) })[:(s:mrw_limit)]
    else
        return []
    endif
endfunction

function! s:mrw_callback(winid, key) abort
    if 0 < a:key
        let lnum = a:key
        let xs = split(getbufline(winbufnr(a:winid), lnum, lnum)[0], s:mrw_delimiter)
        let path = s:fullpath(trim(xs[2]) .. '/' .. trim(xs[1]))
        let matches = filter(getbufinfo(), {i,x -> s:fullpath(x.name) == path })
        if !empty(matches)
            execute printf('%s %d', 'buffer', matches[0]['bufnr'])
        else
            execute printf('%s %s', 'edit', escape(path, ' \'))
        endif
    endif
endfunction

function! s:padding_right_space(text, width)
    return a:text .. repeat(' ', a:width - strdisplaywidth(a:text))
endfunction


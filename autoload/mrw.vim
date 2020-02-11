
function! s:fullpath(path) abort
    return fnamemodify(resolve(a:path), ':p:gs?\\?/?')
endfunction

let s:mrw_cache_path = s:fullpath(expand('<sfile>:h:h') .. '/.mrw.' .. hostname())
let s:mrw_limit = 300
let s:mrw_title = 'mrw'
let s:mrw_delimiter = ' | '
let s:mrw_defaultopt = {
    \   'title' : s:mrw_title,
    \   'pos' : 'center',
    \   'padding' : [1,3,1,3],
    \ }

let s:SORTBY = '-sortby='
let s:SORTBY_TIME = s:SORTBY .. 'time'
let s:SORTBY_FILENAME = s:SORTBY .. 'filename'
let s:SORTBY_DIRECTORY = s:SORTBY .. 'directory'

function! mrw#exec(q_args) abort
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
        " calcate the width of first and second column
        let first_max = 0
        let second_max = 0
        for x in xs
            let ftime = strftime('%c', getftime(x))
            if first_max < strdisplaywidth(ftime)
                let first_max = strdisplaywidth(ftime)
            endif
            let fname = fnamemodify(x, ':t')
            if second_max < strdisplaywidth(fname)
                let second_max = strdisplaywidth(fname)
            endif
        endfor

        " make lines
        let lines = []
        let sorted = []
        if s:SORTBY_FILENAME == trim(a:q_args)
            let sorted = sort(xs, { i1,i2 -> mrw#strcmp(fnamemodify(i1, ':t'), fnamemodify(i2, ':t')) })
        elseif s:SORTBY_DIRECTORY == trim(a:q_args)
            let sorted = sort(xs, { i1,i2 -> mrw#strcmp(fnamemodify(i1, ':h'), fnamemodify(i2, ':h')) })
        else
            " It's -sortby=time
            let sorted = sort(xs, { i1,i2 -> getftime(i2) - getftime(i1) })
        endif
        for x in sorted
            let fname = fnamemodify(x, ':t')
            let dir = fnamemodify(x, ':h')
            let lines += [join([
                \ s:padding_right_space(strftime('%c', getftime(x)), first_max),
                \ s:padding_right_space(fname, second_max),
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
        return filter(readfile(s:mrw_cache_path), { i,x ->
            \ (x != path) && filereadable(x) && (x != s:mrw_cache_path)
            \ })[:(s:mrw_limit)]
    else
        return []
    endif
endfunction

function! mrw#strcmp(x, y) abort
    if a:x == a:y
        return 0
    endif
    for i in range(0, min([len(a:x), len(a:y)]) - 1)
        if char2nr(a:x[i]) < char2nr(a:y[i])
            return -1
        endif
        if char2nr(a:x[i]) > char2nr(a:y[i])
            return 1
        endif
    endfor
    if len(a:x) < len(a:y)
        return -1
    else
        return 1
    endif
endfunction

function! mrw#comp(ArgLead, CmdLine, CursorPos) abort
    let xs = [(s:SORTBY_TIME), (s:SORTBY_FILENAME), (s:SORTBY_DIRECTORY)]
    if -1 == match(a:CmdLine, s:SORTBY .. '\S\+')
        return filter(xs, { i,x -> -1 != match(x, a:ArgLead) })
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


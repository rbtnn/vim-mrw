
function! mrw#exec(q_args) abort
    let xs = mrw#read_cachefile(expand('%'))
    let tstatus = term_getstatus(bufnr())
    if (tstatus != 'finished') && !empty(tstatus)
        call popup_notification('could not open on running terminal buffer', s:mrw_notification_opt)
    elseif !empty(getcmdwintype())
        call popup_notification('could not open on command-line window', s:mrw_notification_opt)
    elseif &modified
        call popup_notification('could not open on modified buffer', s:mrw_notification_opt)
    elseif empty(xs)
        call popup_notification('no most recently written', s:mrw_notification_opt)
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
        if -1 != index(split(a:q_args, '\s\+'), s:SORTBY_FILENAME)
            let sorted = sort(xs, { i1,i2 -> s:strcmp(fnamemodify(i1, ':t'), fnamemodify(i2, ':t')) })
        elseif -1 != index(split(a:q_args, '\s\+'), s:SORTBY_DIRECTORY)
            let sorted = sort(xs, { i1,i2 -> s:strcmp(fnamemodify(i1, ':h'), fnamemodify(i2, ':h')) })
        else
            " It's -sortby=time
            let sorted = sort(xs, { i1,i2 -> getftime(i2) - getftime(i1) })
        endif
        if -1 != index(split(a:q_args, '\s\+'), s:REVERSE)
            let sorted = reverse(sorted)
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

        let winid = popup_menu(lines, s:mrw_menu_opt(s:mrw_title))
        call setwinvar(winid, 'orig_lines', lines)
        call setwinvar(winid, 'filter_text', '')
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

function! mrw#comp(ArgLead, CmdLine, CursorPos) abort
    let xs = []
    let rev = (-1 != stridx(a:CmdLine, s:REVERSE))
    let sortby = v:false
    for x in [(s:SORTBY_TIME), (s:SORTBY_FILENAME), (s:SORTBY_DIRECTORY)]
        if -1 != stridx(a:CmdLine, x)
            let sortby = v:true
            break
        endif
    endfor
    for x in (sortby ? [] : [(s:SORTBY_TIME), (s:SORTBY_FILENAME), (s:SORTBY_DIRECTORY)]) + (rev ? [] : [(s:REVERSE)])
        if -1 == match(a:CmdLine, x)
            let xs += [x]
        endif
    endfor
    return filter(xs, { i,x -> -1 != match(x, a:ArgLead) })
endfunction

function! s:update_lines(winid, F, timer) abort
    let filter_text = a:F()
    if getwinvar(a:winid, 'prev_filter_text') != filter_text
        call setwinvar(a:winid, 'prev_filter_text', filter_text)
        let lines = deepcopy(getwinvar(a:winid, 'orig_lines'))
        call filter(lines, { i,x -> -1 != match(x, filter_text) })
        call setwinvar(a:winid, 'filter_text', trim(filter_text))
        call win_execute(a:winid, 'call clearmatches()')
        if !empty(lines)
            call popup_settext(a:winid, lines)
            call win_execute(a:winid, 'call matchadd("Search", getwinvar(winnr(), "filter_text"))')
        else
            call popup_settext(a:winid, s:NO_MATCHES)
        endif
        call popup_setoptions(a:winid, s:mrw_menu_opt(printf('%s %s%s', s:mrw_title, (empty(filter_text) ? '' : '/'), filter_text)))
        redraw
    endif
endfunction

function! s:mrw_filter(winid, key) abort
    if '/' == a:key
        let timer = timer_start(100, function('s:update_lines', [(a:winid), function('getcmdline')]), #{ repeat: -1, })
        let filter_text = input('/', getwinvar(a:winid, 'filter_text'))
        call timer_stop(timer)
        call s:update_lines(a:winid, {-> filter_text }, timer)
        return 1
    endif
    return popup_filter_menu(a:winid, a:key)
endfunction

function! s:mrw_callback(winid, key) abort
    if 0 < a:key
        let lnum = a:key
        let text = getbufline(winbufnr(a:winid), lnum, lnum)[0]
        if s:NO_MATCHES != text
            let xs = split(text, s:mrw_delimiter)
            let path = s:fullpath(trim(xs[2]) .. '/' .. trim(xs[1]))
            let matches = filter(getbufinfo(), {i,x -> s:fullpath(x.name) == path })
            if !empty(matches)
                execute printf('%s %d', 'buffer', matches[0]['bufnr'])
            else
                execute printf('%s %s', 'edit', escape(path, ' \'))
            endif
        endif
    endif
endfunction

function! s:strcmp(x, y) abort
    return (a:x == a:y) ? 0 : ((a:x < a:y) ? -1 : 1)
endfunction

function! s:padding_right_space(text, width)
    return a:text .. repeat(' ', a:width - strdisplaywidth(a:text))
endfunction

function! s:fullpath(path) abort
    return fnamemodify(resolve(a:path), ':p:gs?\\?/?')
endfunction

function! s:mrw_menu_opt(title) abort
    return {
        \   'close' : 'button',
        \   'maxheight' : &lines * 2 / 3,
        \   'maxwidth' : &columns * 2 / 3,
        \   'padding' : [1,3,1,3],
        \   'pos' : 'center',
        \   'title' : a:title,
        \   'filter' : function('s:mrw_filter'),
        \   'callback' : function('s:mrw_callback'),
        \ }
endfunction

let s:mrw_cache_path = s:fullpath(expand('<sfile>:h:h') .. '/.mrw.' .. hostname())
let s:mrw_limit = 300
let s:mrw_title = 'mrw'
let s:mrw_delimiter = ' | '
let s:mrw_notification_opt = {
    \   'title' : s:mrw_title,
    \   'pos' : 'center',
    \   'padding' : [1,3,1,3],
    \ }

let s:NO_MATCHES = 'no matches'
let s:REVERSE = '-reverse'
let s:SORTBY = '-sortby='
let s:SORTBY_TIME = s:SORTBY .. 'time'
let s:SORTBY_FILENAME = s:SORTBY .. 'filename'
let s:SORTBY_DIRECTORY = s:SORTBY .. 'directory'


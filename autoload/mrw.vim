
let s:REVERSE = '-reverse'
let s:FILENAME_ONLY = '-filename-only'
let s:DIRECTORY_ONLY = '-directory-only'
let s:SORTBY = '-sortby='
let s:NUM = '-N='
let s:FILTER = '-filter='
let s:SORTBY_TIME = s:SORTBY .. 'time'
let s:SORTBY_FILENAME = s:SORTBY .. 'filename'
let s:SORTBY_DIRECTORY = s:SORTBY .. 'directory'
let s:DELIMITER = ' | '

let g:mrw_limit = get(g:, 'mrw_limit', 300)
let g:mrw_cache_path = expand(get(g:, 'mrw_cache_path', '~/.mrw'))

function! mrw#exec(q_args) abort
	try
		let xs = s:read_cachefile('')
		let args = s:parse_arguments(a:q_args)
		call filter(xs, { i,x -> x['path'] =~ args['filter_text'] })

		if empty(xs)
			throw 'No most recently written'
		endif

		" use the old mrw buffer if exists
		let exists = v:false
		for x in getbufinfo()
			if 'mrw' == getbufvar(x['bufnr'], '&filetype', '')
				let exists = v:true
				execute printf('%dbuffer', x['bufnr'])
				break
			endif
		endfor
		if !exists
			silent! edit mrw://output
			setfiletype mrw
			setlocal buftype=nofile bufhidden=hide
		endif

		" make lines
		let sorted = []
		if args['sortby_filename']
			let sorted = sort(xs, { i1,i2 -> s:strcmp(fnamemodify(i1['path'], ':t'), fnamemodify(i2['path'], ':t')) })
		elseif args['sortby_directory']
			let sorted = sort(xs, { i1,i2 -> s:strcmp(fnamemodify(i1['path'], ':h'), fnamemodify(i2['path'], ':h')) })
		else
			" It's -sortby=time
			let sorted = sort(xs, { i1,i2 -> getftime(i2['path']) - getftime(i1['path']) })
		endif

		if args['is_reverse']
			let sorted = reverse(sorted)
		endif

		try
			let &l:statusline = '[MRW] When you want to stop the process, press Ctrl-C!'
			setlocal modifiable noreadonly
			silent! call deletebufline(bufnr(), 1, '$')
			let lnum = 1
			for x in sorted[:((args['num'] ? args['num'] : g:mrw_limit) - 1)]
				let curr_path = x['path']
				let curr_lnum = x['lnum']
				let curr_col = x['col']
				if args['is_fname_only']
					let line = printf('%s(%d,%d)', fnamemodify(curr_path, ':p'), curr_lnum, curr_col)
				else
					" calculate the width of first and second column
					let first_max = 0
					let second_max = 0
					for x in sorted[:((args['num'] ? args['num'] : g:mrw_limit) - 1)]
						let ftime = strftime('%c', getftime(x['path']))
						if first_max < strdisplaywidth(ftime)
							let first_max = strdisplaywidth(ftime)
						endif
						let fname = printf('%s(%d,%d)', fnamemodify(x['path'], ':t'), x['lnum'], x['col'])
						if second_max < strdisplaywidth(fname)
							let second_max = strdisplaywidth(fname)
						endif
					endfor
					let line = join([
						\ s:padding_right_space(strftime('%c', getftime(curr_path)), first_max),
						\ s:padding_right_space(printf('%s(%d,%d)', fnamemodify(curr_path, ':t'), curr_lnum, curr_col), second_max),
						\ fnamemodify(curr_path, ':h'),
						\ ], s:DELIMITER)
				endif
				call setbufline(bufnr(), lnum, line)
				redraw
				let lnum += 1
			endfor
		finally
			let &l:statusline = '[MRW] ' .. a:q_args
			setlocal nomodifiable readonly
		endtry
	catch
		echohl Error
		echo '[mrw]' v:exception
		echohl None
	endtry
endfunction

function! mrw#bufwritepost() abort
	let mrw_cache_path = s:fix_path(g:mrw_cache_path)
	let fullpath = s:fix_path(expand('<afile>'))
	if fullpath != mrw_cache_path
		let p = v:false
		let lnum = line('.')
		let col = col('.')
		if filereadable(mrw_cache_path)
			if filereadable(fullpath)
				let head = readfile(mrw_cache_path, '', 1)
				if 0 < len(head)
					let x = s:line2dict(head[0])
					if ((fullpath != s:fix_path(x['path'])) || (lnum != x['lnum']) || (col != x['col']))
						let p = v:true
					endif
				else
					let p = v:true
				endif
			endif
		else
			let p = v:true
		endif
		if p
			let xs = [json_encode({ 'path': fullpath, 'lnum': lnum, 'col': col, })] + map(s:read_cachefile(fullpath), { i,x -> json_encode(x) })
			call writefile(xs, mrw_cache_path)
		endif
	endif
endfunction

function! mrw#comp(ArgLead, CmdLine, CursorPos) abort
	let xs = []
	let args = s:parse_arguments(a:CmdLine)
	let sortby = v:false
	for x in [(s:SORTBY_TIME), (s:SORTBY_FILENAME), (s:SORTBY_DIRECTORY)]
		if -1 != stridx(a:CmdLine, x)
			let sortby = v:true
			break
		endif
	endfor
	for x in (sortby ? [] : [(s:SORTBY_TIME), (s:SORTBY_FILENAME), (s:SORTBY_DIRECTORY)])
		\ + (args['is_reverse'] ? [] : [(s:REVERSE)])
		\ + (args['is_fname_only'] ? [] : [(s:FILENAME_ONLY)])
		\ + (args['num'] ? [] : [(s:NUM)])
		\ + (args['filter_text'] ? [] : [(s:FILTER)])
		if -1 == match(a:CmdLine, x)
			let xs += [x]
		endif
	endfor
	return filter(xs, { i,x -> -1 != match(x, a:ArgLead) })
endfunction

function! mrw#select() abort
	let xs = split(getbufline(bufnr(), line('.'), line('.'))[0], s:DELIMITER)
	if 1 == len(xs)
		let m = matchlist(s:fix_path(trim(xs[0])), '^\(.\{-\}\)(\(\d\+\),\(\d\+\))$')
	else
		let m = matchlist(s:fix_path(trim(xs[2]) .. '/' .. trim(xs[1])), '^\(.\{-\}\)(\(\d\+\),\(\d\+\))$')
	endif
	if !empty(m)
		call s:open_file(m[1], str2nr(m[2]), str2nr(m[3]))
	endif
endfunction



function! s:parse_arguments(cmdline) abort
	let is_fname_only = -1 != index(split(a:cmdline, '\s\+'), s:FILENAME_ONLY)
	let sortby_filename = -1 != index(split(a:cmdline, '\s\+'), s:SORTBY_FILENAME)
	let sortby_directory = -1 != index(split(a:cmdline, '\s\+'), s:SORTBY_DIRECTORY)
	let is_reverse = -1 != index(split(a:cmdline, '\s\+'), s:REVERSE)
	let num = get(filter(map(split(a:cmdline, '\s\+'), { i,x -> str2nr(matchstr(x, '^' .. s:NUM .. '\zs\d\+$')) }), { i,x -> 0 < x }), 0, 0)
	let filter_text = get(filter(map(split(a:cmdline, '\s\+'), { i,x -> matchstr(x, '^' .. s:FILTER .. '\zs[^ ]\+$') }), { i,x -> !empty(x) }), 0, '')
	return {
		\ 'is_fname_only': is_fname_only,
		\ 'sortby_filename': sortby_filename,
		\ 'sortby_directory': sortby_directory,
		\ 'is_reverse': is_reverse,
		\ 'num': num,
		\ 'filter_text': filter_text,
		\ }
endfunction

function! s:fix_path(path) abort
	return fnamemodify(resolve(a:path), ':p:gs?\\?/?')
endfunction

function! s:read_cachefile(fullpath) abort
	if filereadable(g:mrw_cache_path)
		let lines = readfile(g:mrw_cache_path, '', g:mrw_limit)
		let xs = []
		for i in range(0, len(lines) - 1)
			let x = s:line2dict(lines[i])
			if (a:fullpath != x['path']) && filereadable(x['path'])
				let xs += [x]
			endif
		endfor
		return xs
	else
		return []
	endif
endfunction

function! s:strict_bufnr(path) abort
	let bnr = bufnr(a:path)
	let fname1 = fnamemodify(a:path, ':t')
	let fname2 = fnamemodify(bufname(bnr), ':t')
	if (-1 == bnr) || (fname1 != fname2)
		return -1
	else
		return bnr
	endif
endfunction

function! s:open_file(path, lnum, col) abort
	let bnr = s:strict_bufnr(a:path)
	if -1 == bnr
		execute printf('edit %s', fnameescape(a:path))
	else
		execute printf('buffer %d', bnr)
	endif
	call cursor(a:lnum, a:col)
endfunction

function! s:strcmp(x, y) abort
	return (a:x == a:y) ? 0 : ((a:x < a:y) ? -1 : 1)
endfunction

function! s:padding_right_space(text, width)
	return a:text .. repeat(' ', a:width - strdisplaywidth(a:text))
endfunction

function! s:line2dict(line) abort
	if a:line =~# '^{'
		return json_decode(a:line)
	else
		return { 'path': a:line, 'lnum': 1, 'col': 1, }
	endif
endfunction

if !has('nvim')
	let s:MIN_LNUM = 2
	let s:MAX_LNUM = 10

	function! s:filter(data, winid, key) abort
		let xs = split(get(getbufline(winbufnr(a:winid), 1), 0, ''), '\zs')
		let lnum = line('.', a:winid)
		if 21 == char2nr(a:key)
			" Ctrl-u
			if 1 < len(xs)
				call remove(xs, 1, -1)
				call s:update_window(a:data, a:winid, xs)
			endif
			return 1
		elseif 14 == char2nr(a:key)
			" Ctrl-n
			if lnum == line('$', a:winid)
				call s:set_cursorline(a:winid, s:MIN_LNUM)
			else
				call s:set_cursorline(a:winid, lnum + 1)
			endif
			return 1
		elseif 16 == char2nr(a:key)
			" Ctrl-p
			if lnum == s:MIN_LNUM
				call s:set_cursorline(a:winid, line('$', a:winid))
			else
				call s:set_cursorline(a:winid, lnum - 1)
			endif
			return 1
		elseif (128 == char2nr(a:key)) || (8 == char2nr(a:key))
			" Ctrl-h or bs
			if 1 < len(xs)
				call remove(xs, -1)
				call s:update_window(a:data, a:winid, xs)
			endif
			return 1
		elseif (0x20 <= char2nr(a:key)) && (char2nr(a:key) <= 0x7f)
			let xs += [a:key]
			call s:update_window(a:data, a:winid, xs)
			return 1
		else
			return popup_filter_menu(a:winid, a:key)
		endif
	endfunction

	function! s:update_window(data, winid, xs) abort
		let bnr = winbufnr(a:winid)
		call setbufline(bnr, 1, join(a:xs, ''))
		call setbufline(bnr, s:MIN_LNUM, '')
		call deletebufline(bnr, s:MIN_LNUM + 1, s:MAX_LNUM)
		let n = s:MIN_LNUM
		let pattern = join(a:xs[1:], '')
		try
			for x in a:data
				if empty(pattern) || (x['path'] =~ pattern)
					call setbufline(bnr, n, printf('%s(%d,%d)', x['path'], x['lnum'], x['col']))
					let n += 1
					if s:MAX_LNUM < n
						break
					endif
				endif
			endfor
		catch
			call setbufline(bnr, n, v:exception)
		endtry
	endfunction

	function! s:set_cursorline(winid, lnum) abort
		call win_execute(a:winid, printf('call setpos(".", [0, %d, 0, 0])', a:lnum))
	endfunction

	function! s:callback(winid, result) abort
		let line = get(getbufline(winbufnr(a:winid), a:result), 0, '')
		if !empty(line)
			let m = matchlist(s:fix_path(trim(line)), '^\(.\{-\}\)(\(\d\+\),\(\d\+\))$')
			if !empty(m)
				call s:open_file(m[1], str2nr(m[2]), str2nr(m[3]))
			endif
		endif
	endfunction

	function! mrw#open_popupwin() abort
		let data = s:read_cachefile(s:fix_path(expand('%:p')))
		let winid = popup_menu([], {
			\ 'filter': function('s:filter', [data]),
			\ 'callback': function('s:callback'),
			\ 'pos': 'topleft',
			\ 'line': 1,
			\ 'col': 1,
			\ 'cursorline': v:true,
			\ 'minheight': s:MIN_LNUM,
			\ 'maxheight': s:MAX_LNUM,
			\ 'highlight': 'Normal',
			\ 'border': [1, 1, 1, 1],
			\ })
		call s:update_window(data, winid, ['>'])
		call s:set_cursorline(winid, s:MIN_LNUM)
		call win_execute(winid, 'setfiletype mrw')
	endfunction
endif


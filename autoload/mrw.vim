
let s:REVERSE = '-reverse'
let s:FILENAME_ONLY = '-filename-only'
let s:DIRECTORY_ONLY = '-directory-only'
let s:SORTBY = '-sortby='
let s:NUM = '-N='
let s:SORTBY_TIME = s:SORTBY .. 'time'
let s:SORTBY_FILENAME = s:SORTBY .. 'filename'
let s:SORTBY_DIRECTORY = s:SORTBY .. 'directory'
let s:DELIMITER = ' | '

let g:mrw_limit = get(g:, 'mrw_limit', 300)
let g:mrw_cache_path = expand(get(g:, 'mrw_cache_path', '~/.mrw'))

function! mrw#exec(q_args) abort
	try
		let xs = map(s:read_cachefile(''), { i,x -> json_decode(x) })
		if empty(xs)
			throw 'no most recently written'
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
		let args = s:parse_arguments(a:q_args)
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
			setlocal modifiable noreadonly
			silent! call deletebufline(bufnr(), 1, '$')
			let lnum = 1
			for x in sorted[:(args['num'] - 1)]
				let curr_path = x['path']
				let curr_lnum = x['lnum']
				let curr_col = x['col']
				if args['is_fname_only']
					let line = printf('%s(%d,%d)', fnamemodify(curr_path, ':p'), curr_lnum, curr_col)
				else
					" calculate the width of first and second column
					let first_max = 0
					let second_max = 0
					for x in xs
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
			let xs = [json_encode({ 'path': fullpath, 'lnum': lnum, 'col': col, })] + s:read_cachefile(fullpath)
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
	let num = get(map(split(a:cmdline, '\s\+'), { i,x -> str2nr(matchstr(x, '^' .. s:NUM .. '\zs\d\+$')) }), 0, g:mrw_limit)
	return {
		\ 'is_fname_only': is_fname_only,
		\ 'sortby_filename': sortby_filename,
		\ 'sortby_directory': sortby_directory,
		\ 'is_reverse': is_reverse,
		\ 'num': num,
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
				let xs += [json_encode(x)]
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


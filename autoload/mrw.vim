
let s:REVERSE = '-reverse'
let s:SORTBY = '-sortby='
let s:SORTBY_TIME = s:SORTBY .. 'time'
let s:SORTBY_FILENAME = s:SORTBY .. 'filename'
let s:SORTBY_DIRECTORY = s:SORTBY .. 'directory'

let s:mrw_limit = 300
let s:mrw_delimiter = ' | '

let g:mrw_cache_path = expand(get(g:, 'mrw_cache_path', '~/.mrw'))

function! mrw#exec(q_args) abort
	let xs = mrw#read_cachefile('')
	if empty(xs)
		echohl Error
		echo 'no most recently written'
		echohl None
	else
		try
			enew

			" calculate the width of first and second column
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

			setlocal modifiable noreadonly
			silent! call deletebufline(bufnr(), 1, '$')
			call setbufline(bufnr(), 1, lines)
			setlocal buftype=nofile nomodifiable readonly
			setlocal cursorline
			setfiletype mrw

			nnoremap <buffer><cr>    <Cmd>call mrw#select()<cr>
			nnoremap <buffer><space> <Cmd>call mrw#select()<cr>
		catch
			echohl Error
			echo v:exception
			echohl None
		endtry
	endif
endfunction

function! mrw#bufwritepost() abort
	let path = expand('<afile>')
	if filereadable(path)
		let fullpath = mrw#fix_path(path)
		if fullpath != g:mrw_cache_path
			let head = []
			if filereadable(g:mrw_cache_path)
				let head = readfile(g:mrw_cache_path, '', 1)
			endif
			if empty(head) || (fullpath != mrw#fix_path(get(head, 0, '')))
				let xs = [fullpath] + mrw#read_cachefile(fullpath)
				call writefile(xs, g:mrw_cache_path)
			endif
		endif
	endif
endfunction

function! mrw#read_cachefile(fullpath) abort
	if filereadable(g:mrw_cache_path)
		return filter(readfile(g:mrw_cache_path, '', s:mrw_limit), { i,x ->
			\ (a:fullpath != x) && filereadable(x)
			\ })
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

function! mrw#select() abort
	let text = getbufline(bufnr(), line('.'), line('.'))[0]
	let xs = split(text, s:mrw_delimiter)
	let path = mrw#fix_path(trim(xs[2]) .. '/' .. trim(xs[1]))
	if filereadable(path)
		let bnr = bufnr()
		call s:open_file(path)
		execute printf('%dbwipeout', bnr)
	endif
endfunction

function! mrw#fix_path(path) abort
	return fnamemodify(resolve(a:path), ':p:gs?\\?/?')
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

function! s:open_file(path) abort
	let bnr = s:strict_bufnr(a:path)
	if -1 == bnr
		execute printf('edit %s', fnameescape(a:path))
	else
		silent! execute printf('buffer %d', bnr)
	endif
endfunction

function! s:strcmp(x, y) abort
	return (a:x == a:y) ? 0 : ((a:x < a:y) ? -1 : 1)
endfunction

function! s:padding_right_space(text, width)
	return a:text .. repeat(' ', a:width - strdisplaywidth(a:text))
endfunction


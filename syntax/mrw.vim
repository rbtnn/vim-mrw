if exists("b:current_syntax")
  finish
endif

syntax match   mrwDelimiter   '|'                          contained
syntax match   mrwTime        '^[^|]\+ '                   contained
syntax match   mrwFileName    ' [^|]\+(\d\+,\d\+) '        contained contains=mrwLnumAndCol
syntax match   mrwLnumAndCol  '(\d\+,\d\+)'                contained
syntax match   mrwDirectory   ' [^|]\+$'                   contained
syntax match   nrwLine        '^[^|]\+ | [^|]\+ | [^|]\+$'           contains=mrwFileName,mrwDirectory,mrwTime,mrwDelimiter

highlight default link mrwTime        LineNr
highlight default link mrwFileName    Normal
highlight default link mrwLnumAndCol  Comment
highlight default link mrwDirectory   Directory
highlight default link mrwDelimiter   NonText

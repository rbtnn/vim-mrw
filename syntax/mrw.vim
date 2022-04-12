
if exists("b:current_syntax")
  finish
endif

syntax match   mrwDelimiter   '|'                          contained
syntax match   mrwTime        '^[^|]\+ '                   contained
syntax match   mrwFileName    '[^|]\+(\d\+,\d\+)'          contained  contains=mrwLnumAndCol
syntax match   mrwLnumAndCol  '(\d\+,\d\+)'                contained
syntax match   mrwDirectory   ' [^|]\+$'                   contained

syntax match   mrwLine1        '^[^|]\+ | [^|]\+ | [^|]\+$'  contains=mrwFileName,mrwDirectory,mrwTime,mrwDelimiter
syntax match   mrwLine2        '^[^|]\+(\d\+,\d\+)$'         contains=mrwFileName
syntax match   mrwLine3        '^>.*$'

highlight default link mrwTime        LineNr
highlight default link mrwFileName    Normal
highlight default link mrwLnumAndCol  Comment
highlight default link mrwDirectory   Directory
highlight default link mrwDelimiter   NonText
highlight default link mrwLine3       Directory


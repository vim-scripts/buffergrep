" buffergrep.vim - grep for strings in buffers, not files
" Maintainer:       Erik Falor <ewfalor@gmail.com>
" Date:             2008-07-17
" Version:          1.1
" License:          Vim license


" History: {{{
"   Version 1.1:        Bugfixes: TabSearch now reaches all files,
"                       Regex delimiter around arguments now optional
"   
"   Version 1.0:        Initial upload
"}}}

"TODO list {{{
"3. x factor out common code into helper functions
"4.   combine into 1 function so reduplication is avoided
"5.   make error messages appear identical to :vimgrep errors
"6.   Add a u flag to grep options that allows user to grep in 
"     unlisted buffers.
"7.   should move cursor to already open window instead of changing
"     current window to view first qf item
"8. X Fix inconsistancy with regex delimiters
"9. X Tgrep doesn't find some matches
"10.  Add commands or args to add results to location list instead
"     of quickfix list.
"}}}

" Initialization: {{{
if exists("g:loaded_buffergrep")
    finish
endif
let g:loaded_buffergrep = "1.1"

let s:keepcpo = &cpo
set cpo&vim
let s:notIdents = split("!\"#$%&'()*+,-./:;<=>?@[\]^`{|}~貝物洎悖停眾斯須號獄播噶釬", '\zs')
"}}}

function! s:ParsePattern(pattern) "{{{
    ""detect presense of regex pattern delimiter or :vimgrep flags

    "set flags to default values
    let glbl = ''
    let jmp = 1
    let dlmtd = 0

    "the pattern delimiter is the first char provided in a:pattern
    let patEnd = stridx(a:pattern, strpart(a:pattern, 0, 1), 1)
    if patEnd == -1
        "if first character doesn't occur again in pattern, then
        "the user likely meant not to delimit the pattern; Check 
        "that pattern begins with an ID character
        if a:pattern =~ '^\i'
            "Pattern begins with ID char; it is not delimited
            "
            "The pattern must be delimited so we can use the j flag with
            ":vimgrepadd
            "
            "Find a non-identifer character that is not in a:pattern
            let foundDelimiter = 0
            for c in s:notIdents
                if -1 == stridx(a:pattern, c)
                    let pat = c . a:pattern . c
                    let foundDelimiter = 1
                    break
                endif
            endfor

            if !foundDelimiter
                "bail out here; otherwise an undelimited pattern will
                "result in :vimgrepadd failing later on
                throw "Could not delimit pattern '". a:pattern ."'"
            endif
        else
            "incorrectly delimited pattern; throw error
            throw "E682: Invalid search pattern or delimiter"
        endif
    else
        "grab the pattern, sans the flags
        let pat = strpart(a:pattern, 0, patEnd + 1)
        let dlmtd = 1
        "set flags
        let flags = strpart(a:pattern, patEnd + 1) 
        if -1 < stridx(flags, 'g') | let glbl = 'g' | endif
        if -1 < stridx(flags, 'j') | let jmp  = 0   | endif
    endif

    return [pat, glbl, jmp]
endfunction "}}}

" Search in all listed buffers
function! BufSearch(pattern, bang) "{{{
    let [trimPat, global, jmp] = s:ParsePattern(a:pattern)

    "save the original view
    let [origbuf, origview] = [bufnr("%"), winsaveview()]
    let foldenableSave = &foldenable
    set nofoldenable

    "create a new, empty quickfix list
    call setqflist([])

    "find the last unlisted buffer
    let lastbuf = bufnr("$")

    "loop through all buffers reachable with bnext
    bfirst
    while 1 
        if &buftype !~ '^help$\|^quickfix$\|^unlisted$'
            try
                exec "silent vimgrepadd" . a:bang . " " . trimPat . global ."j %" 
            catch /^Vim\%((\a\+)\)\=:E480/   " No Match
                "ignore it, and move on to the next file
            catch /^Vim\%((\a\+)\)\=:E499/   " Empty file name for %
                "shouldn't happen; but we'll just move on to the next buffer
            endtry
        endif
        if bufnr("%") == lastbuf
            break
        else
            bnext
        endif
    endwhile

    "restore the original view for the active window or jump to first match
    exec "buffer " . origbuf
    let &foldenable = foldenableSave
    call winrestview(origview)
    if getqflist() == [] 
        echoe "E480: No Match: " . trimPat
    elseif jmp == 1
        cc 
    endif
endfunction "}}}
command! -nargs=1 -bang Bgrep call BufSearch(<q-args>, "<bang>")

" Search in argslist files
function! ArgSearch(pattern, bang) "{{{

    let [trimPat, global, jmp] = s:ParsePattern(a:pattern)

    "save the original view
    let [origbuf, origview] = [bufnr("%"), winsaveview()]
    let foldenableSave = &foldenable
    set nofoldenable

    "create a new, empty quickfix list
    call setqflist([])

    "find the bufnr of the last file argument
    let lastbuf = bufnr(argv(argc() - 1))

    "loop through all files in args list
    let visitedBuffers= {}
    first
    try
        while 1 
            if &buftype !~ '^help$\|^quickfix$\|^unlisted$' && !has_key(visitedBuffers, bufname('%'))
                let visitedBuffers[bufname('%')] = 1
                try
                    exec "silent vimgrepadd" . a:bang . " " . trimPat . global ."j %" 
                catch /^Vim\%((\a\+)\)\=:E480/   " No Match
                    "ignore it, and move on to the next file
                catch /^Vim\%((\a\+)\)\=:E499/   " Empty file name for %
                    "shouldn't happen; but we'll just move on to the next
                endtry
            endif
            if bufnr("%") == lastbuf
                break
            else
                next
            endif
        endwhile
    catch /^Vim\%((\a\+)\)\=:E165/   " Cannot go beyond last file
        "well, now that we're out of the loop... no need to alarm the user
    endtry

    "restore the original view for the active window or jump to first match
    exec "buffer " . origbuf
    let &foldenable = foldenableSave
    call winrestview(origview)
    if getqflist() == [] 
        echoe "E480: No Match: " . trimPat
    elseif jmp == 1
        cc 
    endif
endfunction "}}}
command! -nargs=1 -bang Agrep call ArgSearch(<q-args>, "<bang>")

" Search in all buffers open in all visible windows (single tabpage)
function! WinSearch(pattern, bang) "{{{

    let [trimPat, global, jmp] = s:ParsePattern(a:pattern)

    "save the original view
    let [origwin, origview] = [winnr(), winsaveview()]
    let foldenableSave = &foldenable
    set nofoldenable

    "create a new, empty quickfix list
    call setqflist([])

    "find the last unlisted buffer
    let lastbuf = winnr("$")
    let visitedBuffers = {}

    "loop through all visible windows
    for winNumber in range(1, winnr('$'))
        if has_key(visitedBuffers, winbufnr(winNumber))
            continue
        endif
        let visitedBuffers[ winbufnr(winNumber) ] = 1

        "make into active window for vimgrep command
        execute winNumber . "wincmd w"

        if &buftype !~ '^help$\|^quickfix$\|^unlisted$'
            try
                exec "silent vimgrepadd" . a:bang . " " . trimPat . global ."j %" 
            catch /^Vim\%((\a\+)\)\=:E480/   " No Match
                "ignore it, and move on to the next file
            catch /^Vim\%((\a\+)\)\=:E499/   " Empty file name for %
                "shouldn't happen; but we'll just move on to the next
            endtry
        endif
    endfor

    "restore the original view for the active window or jump to first match
    execute origwin . "wincmd w"
    let &foldenable = foldenableSave
    call winrestview(origview)
    if getqflist() == [] 
        echoe "E480: No Match: " . trimPat
    elseif jmp == 1
        cc 
    endif
endfunction "}}}
command! -nargs=1 -bang Wgrep call WinSearch(<q-args>, "<bang>")

" Search in all buffers open in all tabs
function! TabSearch(pattern, bang) "{{{
    let [trimPat, global, jmp] = s:ParsePattern(a:pattern)

    "save the original view
    let [origbuf, origview] = [bufnr("%"), winsaveview()]
    let foldenableSave = &foldenable
    set nofoldenable

    "create a new, empty quickfix list
    call setqflist([])

    let visitedBuffers = {}

    "loop through all tabpages...
    for tabNumber in range(1, tabpagenr('$'))
        "loop through all buffers in each tabpage...
        for bufNumber in tabpagebuflist(tabNumber)
            if has_key(visitedBuffers, bufNumber) 
                continue
            endif
            let visitedBuffers[ bufNumber ] = 1
            "navagate into the buffer in order to do the vimgrep
            let oldBuf = bufnr("%")
            execute 'buffer ' . bufNumber

            if &buftype !~ '^help$\|^quickfix$\|^unlisted$'
                try
                    exec "silent vimgrepadd" . a:bang . " " . trimPat . global ."j %" 
                catch /^Vim\%((\a\+)\)\=:E480/   " No Match
                    "ignore it, and move on to the next file
                catch /^Vim\%((\a\+)\)\=:E499/   " Empty file name for %
                    "shouldn't happen; but we'll just move on to the next
                endtry
                execute 'buffer ' . oldBuf
            endif
        endfor
    endfor

    "restore the original view for the active window or jump to first match
    exec "buffer " . origbuf
    let &foldenable = foldenableSave
    call winrestview(origview)
    if getqflist() == [] 
        echoe "E480: No Match: " . trimPat
    elseif jmp == 1
        cc 
    endif
endfunction "}}}
command! -nargs=1 -bang Tgrep call TabSearch(<q-args>, "<bang>")

" Restore &cpo: {{{
let &cpo= s:keepcpo
unlet s:keepcpo
"}}}

"  vim: tabstop=4 shiftwidth=4 foldmethod=marker expandtab fileformat=unix:

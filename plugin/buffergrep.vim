" buffergrep.vim - grep for strings in buffers, not files
" Maintainer:       Erik Falor <ewfalor@gmail.com>
" Date:             2008-06-02
" Version:          1.0
" License:          Vim license


" History: {{{
"
"   Version 1.0:        Initial upload
"}}}

"TODO list {{{
"3.  factor out common code into helper functions
"4.  combine into 1 function so reduplication is avoided
"5.  make error messages appear identical to :vimgrep errors
"6.  add flag to allow searching in "unlisted" buffers
"7.  should move cursor to already open window instead of changing
"    current window to view first qf item
"8.  Add a u flag to grep options that allows user to grep in 
"    unlisted buffers.
"}}}

" Initialization: {{{
if exists("g:loaded_buffergrep")
    finish
endif
let g:loaded_buffergrep = "1.0"

let s:keepcpo      = &cpo
set cpo&vim
"}}}

" Search in all listed buffers
function! BufSearch(pattern, bang) "{{{
    ""detect whether the user passed any :vimgrep flags 
    "the pattern delimiter is the first char provided in a:pattern
    let patEnd = stridx(a:pattern, strpart(a:pattern, 0, 1), 1)
    let flags = strpart(a:pattern, patEnd + 1) 
    "grab the pattern, sans the flags
    let trimPat = strpart(a:pattern, 0, patEnd + 1)

    let [global, nojump] = ['', 0]
    if -1 < stridx(flags, 'g') | let global = 'g' | endif
    if -1 < stridx(flags, 'j') | let nojump = 1   | endif

    "save the original view
    let [origbuf, origview] = [bufnr("%"), winsaveview()]
    let foldenableSave = &foldenable
    set nofoldenable

    "create a new, empty quickfix list
    call setqflist([])

    "find the last unlisted buffer
    blast
    let lastbuf = bufnr("%")

    "loop through all buffers reachable with bnext
    bfirst
    while 1 
        if &buftype !~ '^help$\|^quickfix$\|^unlisted$'
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
            bnext
        endif
    endwhile

    "restore the original view for the active window or jump to first match
    exec "buffer " . origbuf
    let &foldenable = foldenableSave
    call winrestview(origview)
    if !nojump
        if getqflist() == [] 
            echoe "E480: No Match: " . trimPat
        else
            cc 
        endif
    endif
endfunction "}}}
command! -nargs=1 -bang Bgrep call BufSearch(<q-args>, "<bang>")

" Search in argslist files
function! ArgSearch(pattern, bang) "{{{
    ""detect whether the user passed any :vimgrep flags 
    "the pattern delimiter is the first char provided in a:pattern
    let patEnd = stridx(a:pattern, strpart(a:pattern, 0, 1), 1)
    let flags = strpart(a:pattern, patEnd + 1) 
    "grab the pattern, sans the flags
    let trimPat = strpart(a:pattern, 0, patEnd + 1)

    let [global, nojump] = ['', 0]
    if -1 < stridx(flags, 'g') | let global = 'g' | endif
    if -1 < stridx(flags, 'j') | let nojump = 1   | endif

    "save the original view
    let [origbuf, origview] = [bufnr("%"), winsaveview()]
    let foldenableSave = &foldenable
    set nofoldenable

    "create a new, empty quickfix list
    call setqflist([])

    "find the last file argument
    last
    let lastbuf = bufnr("%")
    "call Decho("lastbuf = " . lastbuf)

    "loop through all files in args list
    let visitedBuffers= {}
    first
    while 1 
        "call Decho("checking &buftype for " . bufname("%") . "(" . bufnr("%") . ")")
        if &buftype !~ '^help$\|^quickfix$\|^unlisted$' && !has_key(visitedBuffers, bufname('%'))
            "call Decho("scanning file " . bufname("%") . "(" . bufnr("%") . ")" )
            let visitedBuffers[bufname('%')] = 1
            try
                "call Decho( "silent vimgrepadd" . a:bang . " " . trimPat . global ."j %" )
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

    "restore the original view for the active window or jump to first match
    exec "buffer " . origbuf
    let &foldenable = foldenableSave
    call winrestview(origview)
    if !nojump
        if getqflist() == [] 
            throw "E480: No Match: " . trimPat
        else
            cc 
        endif
    endif
endfunction "}}}
command! -nargs=1 -bang Agrep call ArgSearch(<q-args>, "<bang>")

" Search in all buffers open in all visible windows (single tabpage)
function! WinSearch(pattern, bang) "{{{
    ""detect whether the user passed any :vimgrep flags 
    "the pattern delimiter is the first char provided in a:pattern
    let patEnd = stridx(a:pattern, strpart(a:pattern, 0, 1), 1)
    let flags = strpart(a:pattern, patEnd + 1) 
    "grab the pattern, sans the flags
    let trimPat = strpart(a:pattern, 0, patEnd + 1)

    let [global, nojump] = ['', 0]
    if -1 < stridx(flags, 'g') | let global = 'g' | endif
    if -1 < stridx(flags, 'j') | let nojump = 1   | endif

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
            "call Decho("already visited " . bufname(winbufnr(winNumber)) )
            continue
        endif
        let visitedBuffers[ winbufnr(winNumber) ] = 1

        "make into active window for vimgrep command
        execute winNumber . "wincmd w"

        "call Decho("buffer " . bufname(winbufnr(winNumber)) . " has &buftype of '" . &buftype . "'")
        if &buftype !~ '^help$\|^quickfix$\|^unlisted$'
            "call Decho("searching in " . bufname(winbufnr(winNumber)) )
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
    if !nojump
        if getqflist() == [] 
            echoe "E480: No Match: " . trimPat
        else
            "instead of simply jumping, move cursor to the window that already
            "has this open...
            "what if we have the file open in many windows?
            "what if the file is already open in the current window?  just jump
            "otherwise, navigate to "nearest" window and jump then...
            cc 
        endif
    endif
endfunction "}}}
command! -nargs=1 -bang Wgrep call WinSearch(<q-args>, "<bang>")

" Search in all buffers open in all tabs
function! TabSearch(pattern, bang) "{{{
    ""detect whether the user passed any :vimgrep flags 
    "the pattern delimiter is the first char provided in a:pattern
    let patEnd = stridx(a:pattern, strpart(a:pattern, 0, 1), 1)
    let flags = strpart(a:pattern, patEnd + 1) 
    "grab the pattern, sans the flags
    let trimPat = strpart(a:pattern, 0, patEnd + 1)

    let [global, nojump] = ['', 0]
    if -1 < stridx(flags, 'g') | let global = 'g' | endif
    if -1 < stridx(flags, 'j') | let nojump = 1   | endif

    "save the original view
    let [origbuf, origview] = [bufnr("%"), winsaveview()]
    let foldenableSave = &foldenable
    set nofoldenable

    "create a new, empty quickfix list
    call setqflist([])

    "find the last unlisted buffer
    blast
    let lastbuf = bufnr("%")
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
            execute 'buffer ' . bufNumber

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
    endfor

    "restore the original view for the active window or jump to first match
    exec "buffer " . origbuf
    let &foldenable = foldenableSave
    call winrestview(origview)
    if !nojump
        if getqflist() == [] 
            echoe "E480: No Match: " . trimPat
        else
            cc 
        endif
    endif
endfunction "}}}
command! -nargs=1 -bang Tgrep call TabSearch(<q-args>, "<bang>")

" Restore &cpo: {{{
let &cpo= s:keepcpo
unlet s:keepcpo
"}}}

"  vim: tabstop=4 shiftwidth=4 foldmethod=marker expandtab fileformat=unix:

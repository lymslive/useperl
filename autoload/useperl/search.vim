" File: search
" Author: lymslive
" Description: search using perl style regexp
" Create: 2018-08-16
" Modify: 2018-08-16

let s:ifperl = useperl#ifperl#pack()

" Commander: 
function! useperl#search#Commander(...) abort "{{{
    if a:0 == 0 || empty(a:1) || a:1 == '/'
        if has_key(b:, 'PerlSearch')
            let b:PerlSearch = {}
        endif
        return s:UnmapNext()
    endif

    let l:pattern = a:1
    if l:pattern =~ '^/'
        let l:pattern = l:pattern[1:]
    endif

    let l:pattern = s:ifperl.QuoteSingle(l:pattern)
    let l:strOut = s:ifperl.call('SearchLine', l:pattern)
    if empty(l:strOut)
        return
    endif

    let l:lsOut = split(l:strOut, "\n")
    call s:InitResult(l:pattern, l:lsOut)
endfunction "}}}

" InitResult: 
function! s:InitResult(pattern, result) abort "{{{
    let b:PerlSearch = {}
    let b:PerlSearch.pattern = ''
    let b:PerlSearch.result = []
    let b:PerlSearch.pattern = a:pattern
    let b:PerlSearch.result = a:result

    call setloclist(0, [], 'r', {'efm': "%f:%l|%c %m", 'lines': b:PerlSearch.result})
    call s:RemapNext()
    call s:next()
endfunction "}}}

" next: 
function! s:next() abort "{{{
    if !has_key(b:, 'PerlSearch') || empty(get(b:PerlSearch, 'result', []))
        return
    endif
    let l:curline = line('.')
    let l:length = len(b:PerlSearch.result)
    let l:idx = 0
    while l:idx < l:length
        let l:str = b:PerlSearch.result[l:idx]
        let l:idx += 1
        let l:lsMatch = matchlist(l:str, ':\(\d\+\)|\(\d\+\)\s*\(.*\)')
        if empty(l:lsMatch)
            continue
        endif
        let l:linenr = l:lsMatch[1]
        let l:column = l:lsMatch[2]
        let l:match = l:lsMatch[3]
        if l:linenr > l:curline
            call cursor(l:linenr, l:column+1)
            let l:match = substitute(l:match, '[\.*]', '\\&', 'g')
            let l:cmd = 'match Search /' . l:match . '/'
            execute l:cmd
            return
        endif
    endwhile
    echo 'search to the end, not find any more:' b:PerlSearch.pattern
endfunction "}}}

" Next: 
function! s:Next() abort "{{{
    if !has_key(b:, 'PerlSearch') || empty(get(b:PerlSearch, 'result', []))
        return
    endif
    let l:curline = line('.')
    let l:length = len(b:PerlSearch.result)
    let l:idx = l:length - 1
    while l:idx >= 0
        let l:str = b:PerlSearch.result[l:idx]
        let l:idx -= 1
        let l:lsMatch = matchlist(l:str, ':\(\d\+\)|\(\d\+\)\s*\(.*\)')
        if empty(l:lsMatch)
            continue
        endif
        let l:linenr = l:lsMatch[1]
        let l:column = l:lsMatch[2]
        let l:match = l:lsMatch[3]
        if l:linenr < l:curline
            call cursor(l:linenr, l:column+1)
            let l:match = substitute(l:match, '[\.*]', '\\&', 'g')
            let l:cmd = 'match Search /' . l:match . '/'
            execute l:cmd
            return
        endif
    endwhile
    echo 'search to the end, not find any more:' b:PerlSearch.pattern
endfunction "}}}

" RemapNext: 
function! s:RemapNext() abort "{{{
    nnoremap <buffer> n :call <SID>next()<CR>
    nnoremap <buffer> N :call <SID>Next()<CR>
    echomsg 'normal n has remaped to search perl regexp: ' . b:PerlSearch.pattern
endfunction "}}}

" UnmapNext: 
function! s:UnmapNext() abort "{{{
    nunmap <buffer> n
    nunmap <buffer> N
    match none
    echomsg 'normal n has restored to default'
endfunction "}}}


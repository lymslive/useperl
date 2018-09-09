" File: data
" Author: lymslive
" Description: manage to load static data for omni completion
" Create: 2018-09-08
" Modify: 2018-09-08


let s:static = {}
let s:pack = {}
function! useperl#perlomni#data#pack() abort "{{{
    return s:pack
endfunction "}}}

" GetData: 
function! s:GetData(key) abort "{{{
    let l:dot = stridx(a:key, '.')
    if l:dot > -1
        let l:file = strpart(a:key, 0, l:dot)
        let l:key = strpart(a:key, l:dot + 1)
    else
        let l:file = a:key
        let l:key = ''
    endif

    if !has_key(s:static, l:file)
        call s:readpod(l:file)
    endif

    if has_key(s:static, l:file)
        if empty(l:key)
            return s:static[l:file]
        else
            return get(s:static[l:file], l:key, [])
        endif
    else
        :DLOG 'fails to read pod data file: ' . l:file
        return []
    endif
endfunction "}}}
let s:pack.GetData = function('s:GetData')

" readpod: 
function! s:readpod(file) abort "{{{
    if a:file !~ '^[\w]'
        :DLOG 'invalid file name: ' . a:file
        return
    endif

    let l:file = useperl#plugin#dir() . '/perlomni/data/' . a:file . '.pod'
    if !filereadable(l:file)
        let l:dir = useperl#plugin#dir() . '/perlomni/data'
        let l:cmd = printf('make %s -C "%s"', a:file . '.pod', l:dir)
        :DLOG 'will build data $' . l:cmd
        call system(l:cmd)
        if v:shell_error
            :DLOG 'shell make error'
            return
        endif
    endif
    if !filereadable(l:file)
        :ELOG 'file isnot readable: ' . l:file
    endif

    let l:lsConent = readfile(l:file)
    if !empty(l:lsConent)
        let l:result = s:parsepod(l:lsConent)
        if empty(l:result)
            :DLOG 'seams read in empty data?'
            return
        endif
        let s:static[a:file] = l:result
    endif
endfunction "}}}

" parsepod: 
function! s:parsepod(list) abort "{{{
    if empty(a:list) || type(a:list) != type([])
        return {}
    endif

    let l:data = {}
    let l:key = ''
    let l:start = -1
    let l:stop = -1

    let l:iend = len(a:list)
    let l:idx = 0
    while l:idx < l:iend
        let l:line = a:list[l:idx]
        let l:idx += 1

        " just reach the end, extract the last item data
        if l:idx >= l:iend
            let l:stop = l:idx - 1
            if l:line =~? '^=item\s\+'
                let l:stop -= 1
            endif
            if !empty(l:key) && l:start >= 0
                let l:data[l:key] = s:slicepod(a:list, l:start, l:stop)
            else
                " no =item, simple list instead
                let l:key = 'list'
                let l:data[l:key] = s:slicepod(a:list, 0, l:stop)
            endif
            break
        endif

        if l:line !~? '^=item\s\+'
            continue
        endif

        let l:words = split(l:line)
        if len(l:words) < 2
            continue
        endif
        call remove(l:words, 0) " drop =item

        if !empty(l:key) && l:start >=0
            let l:stop = l:idx - 2 " l:idx has move next to =item line
            let l:data[l:key] = s:slicepod(a:list, l:start, l:stop)
        endif

        " switch to new item data
        let l:key = l:words[1]
        let l:start = l:idx
        let l:stop = l:start
    endwhile

    return l:data
endfunction "}}}

" slicepod: return a sublist btween in [first, last], 
" and trim empty line in tow ends
function! s:slicepod(list, first, last) abort "{{{
    if a:last < a:first
        :DLOG 'invalid empty data? a:last < a:first'
        return []
    endif

    let l:first = a:first
    let l:last = a:last
    let l:iend = len(a:list)
    while l:first <= l:last && l:first < l:iend && empty(a:list[l:first])
        let l:first += 1
    endwhile
    while l:last >= l:first && l:last >= 0 && empty(a:list[l:last])
        let l:last -= 1
    endwhile

    if l:last < l:first
        :DLOG 'invalid empty data? a:last < a:first'
        return []
    endif

    return a:list[l:first : l:last]
endfunction "}}}

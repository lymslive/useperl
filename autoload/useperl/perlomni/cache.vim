" File: cache
" Author: lymslive
" Description: dynaminc data cache for perl omni completion
" Create: 2018-09-08
" Modify: 2018-09-08

" Package: 
let s:pack = {}
function! useperl#perlomni#cache#pack() abort
    return s:pack
endfunction

" the key in cache dict is a string, but may joined from several substring
" usually contains namespace and key
let g:perlomni_cache = {}
let s:GAP = '|'

let s:last_cache_ts = localtime()
let s:cache_expiry =  { }
let s:cache_last   =  { }

" Cache Config: default expiry time of namespace (key prefix)
let s:expiry = {}
let s:expiry.ClassLocal = 150
let s:expiry.ClassPre = 60
let s:expiry.Variables = 60
let s:expiry.VarArray = 60
let s:expiry.VarHash = 60
let s:expiry.ClassLocal = 600
let s:expiry.CurrentImport = 300
let s:expiry.ModuleExport = 3600
let s:expiry.BufferFunction = 300
let s:expiry.ClassFile = 600
let s:expiry.ClassBased = 600
let s:expiry.CurrentBased = 60
let s:expiry.ClassFunction = 120
let s:expiry.ClassFuncSingle = 300

function! s:GetCache(...) "{{{
    if !g:perlomni_use_cache
        return 0
    endif

    if a:0 < 1
        return 0
    endif

    let key = join(a:000, s:GAP)
    if !has_key(g:perlomni_cache, key)
        return 0
    endif

    let l:cache = get(g:perlomni_cache, key, 0)
    if empty(l:cache)
        return 0
    endif

    let l:expiry = get(s:cache_expiry, key, g:perlomni_cache_expiry)
    let last_ts = get(s:cache_last, key, s:last_cache_ts)

    " clear expiry key
    if localtime() - last_ts > expiry
        if has_key( s:cache_expiry , key )
            let s:cache_last[ key ] = localtime()
        else
            let s:last_cache_ts = localtime()
        endif
        let g:perlomni_cache[key] = 0
        if has_key(s:cache_expiry , key)
            let s:cache_expiry[key] = 0
        endif
        return 0
    endif

    return l:cache
endfunction "}}}
let s:pack.GetCache = function('s:GetCache')

function! s:SetCache(value, ...) "{{{
    if !g:perlomni_use_cache
        return a:value
    endif

    if empty(a:value) || a:0 < 1
        return a:value
    endif

    let l:namespace = a:1
    let l:expiry = get(s:expiry, l:namespace, 0)
    if !empty(l:expiry)
        let l:args = [a:value, l:expiry] + a:000
        return call(function('s:SetCacheExpiry'), l:args)
    endif

    let key = join(a:000, s:GAP)
    if empty(key)
        return a:value
    endif

    if ! exists('g:perlomni_cache')
        let g:perlomni_cache = { }
    endif
    let g:perlomni_cache[ key ] = a:value
    return a:value
endfunction "}}}
let s:pack.SetCache = function('s:SetCache')

function! s:SetCacheExpiry(value,exp, ...) "{{{
    let key = join(a:000, s:GAP)
    if empty(key)
        return a:value
    endif

    if ! exists('g:perlomni_cache')
        let g:perlomni_cache = { }
    endif
    let g:perlomni_cache[ key ] = a:value
    let s:cache_expiry[ key ] = a:exp
    let s:cache_last[ key ] = localtime()
    return a:value
endfunction "}}}
let s:pack.SetCacheExpiry = function('s:SetCacheExpiry')

" CheckExpiry: 
function! s:CheckExpiry() abort "{{{
    let l:now = localtime()
    for [key, cache] in items(g:perlomni_cache)
        let l:expiry = get(s:cache_expiry, key, 0)
        let l:last_ts = get(s:cache_last, key, 0)
        if l:expiry > 0 && l:last_ts > 0 && l:now - l:last_ts > l:expiry
            let g:perlomni_cache[key] = 0
            let s:cache_expiry[key] = 0
        endif
        unlet key 
    endfor
endfunction "}}}

" ClearCache: 
function! s:ClearCache(...) abort "{{{
    if a:0 > 0 && !empty(a:1)
        return s:CheckExpiry()
    endif
    let g:perlomni_cache = { }
    let s:cache_expiry =  { }
    let s:cache_last   =  { }
endfunction "}}}
command! -nargs=? PerlOmniCacheClear  :call s:ClearCache(<f-args>)

" ViewCache: 
function! s:ViewCache(...) abort "{{{
    if !exists('g:perlomni_cache')
        echo 'no g:perlomni_cache at all'
        return
    endif
    if a:0 == 0
        for l:key in sort(keys(g:perlomni_cache))
            echo l:key
        endfor
    else
        if empty(a:1) || a:1 == '0'
            echo 'g:perlomni_cache has cached ' . len(g:perlomni_cache) . ' keys'
        else
            let l:key = a:1
            let l:buf = matchstr(l:key, s:GAP . '\zs\d\+\ze')
            let l:show = l:key
            if !empty(l:buf)
                let l:show .= ':' . l:buf
            endif
            echo l:show . ' = ' . string(g:perlomni_cache[l:key])
        endif
    endif
endfunction "}}}
" ViewCacheComp: 
function! s:ViewCacheComp(A, L, P) abort "{{{
    if !exists('g:perlomni_cache')
        return ''
    endif
    return join(keys(g:perlomni_cache), "\n")
endfunction "}}}
command! -nargs=* -complete=custom,s:ViewCacheComp PerlOmniCacheView call s:ViewCache(<f-args>)


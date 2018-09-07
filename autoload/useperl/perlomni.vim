" File: perlomni
" Author: lymslive
" Description: perl omni completion
"   based on: https://github.com/c9s/perlomni.vim
" Create: 2018-08-29
" Modify: 2018-08-29

" Package: 
let s:pack = {}
function! useperl#perlomni#pack() abort "{{{
    return s:pack
endfunction

" Check Environment: {{{1
function! s:findBin(script)
    let l:thisdir = useperl#plugin#dir()
    let l:bins = split(globpath(l:thisdir, 'bin/'.a:script), "\n")
    if len(l:bins) == 0
        let l:bins = split(globpath(&rtp, 'bin/'.a:script), "\n")
    endif
    if len(l:bins) == 0
        return ''
    endif
    return l:bins[0][:-len(a:script)-1]
endfunction

" find the bin dir (with tail /)
let s:vimbin = s:findBin('grep-objvar.pl')
if len(s:vimbin) == 0
    echo "Not find script in local bin/"
    echo "Please install scripts to ~/.vim/bin"
    finish
endif

" Configurations: {{{1
function! s:defopt(name,value)
    if !exists('g:{a:name}')
        let g:{a:name} = a:value
    endif
endfunction
cal s:defopt('perlomni_enable_ifperl', has('perl'))
cal s:defopt('perlomni_cache_expiry',30)
cal s:defopt('perlomni_max_class_length',40)
cal s:defopt('perlomni_sort_class_by_lenth',0)
cal s:defopt('perlomni_use_cache',1)
cal s:defopt('perlomni_use_perlinc',1)
cal s:defopt('perlomni_show_hidden_func',0)
cal s:defopt('perlomni_perl','perl')
cal s:defopt('perlomni_export_functions','1')

" Cache Mechanism: {{{1
let s:last_cache_ts = localtime()
let s:cache_expiry =  { }
let s:cache_last   =  { }

function! s:GetCacheNS(ns,key) "{{{
    let key = a:ns . "_" . a:key
    if has_key( s:cache_expiry , key )
        let expiry = s:cache_expiry[ key ]
        let last_ts = s:cache_last[ key ]
    else
        let expiry = g:perlomni_cache_expiry
        let last_ts = s:last_cache_ts
    endif

    if localtime() - last_ts > expiry
        if has_key( s:cache_expiry , key )
            let s:cache_last[ key ] = localtime()
        else
            let s:last_cache_ts = localtime()
        endif
        return 0
    endif

    if ! g:perlomni_use_cache
        return 0
    endif
    if exists('g:perlomni_cache[key]')
        return g:perlomni_cache[key]
    endif
    return 0
endfunction "}}}
let s:pack.GetCacheNS = function('s:GetCacheNS')

function! s:SetCacheNS(ns,key,value) "{{{
    if ! exists('g:perlomni_cache')
        let g:perlomni_cache = { }
    endif
    let key = a:ns . "_" . a:key
    let g:perlomni_cache[ key ] = a:value
    return a:value
endfunction "}}}
let s:pack.SetCacheNS = function('s:SetCacheNS')

function! s:SetCacheNSWithExpiry(ns,key,value,exp) "{{{
    if ! exists('g:perlomni_cache')
        let g:perlomni_cache = { }
    endif
    let key = a:ns . "_" . a:key
    let g:perlomni_cache[ key ] = a:value
    let s:cache_expiry[ key ] = a:exp
    let s:cache_last[ key ] = localtime()
    return a:value
endfunction "}}}
let s:pack.SetCacheNSWithExpiry = function('s:SetCacheNSWithExpiry')

command! PerlOmniCacheClear  :unlet g:perlomni_cache

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
            echo a:1 . ' = ' . string(g:perlomni_cache[a:1])
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

" Complete API: {{{1

" Available Rule attributes
"   only:
"       if one rule is matched, then rest rules won't be check.
"   contains:
"       if file contains some string (can be regexp)
"   context:
"       completion context pattern
"   backward:
"       regexp for moving cursor back to the completion position.
"   head:
"       pattern that matches paragraph head.
"   comp:
"       completion function reference.
let s:rules = [ ]
function! s:rule(hash)
    cal add( s:rules , a:hash )
endfunction
let s:pack.AddRule = function('s:rule')

" Main Completion Function:
" b:context  : whole current line
" b:lcontext : the text before cursor position
" b:colpos   : cursor position - 1
" b:lines    : range of scanning
function! PerlComplete(findstart, base) "{{{
    if ! exists('b:lines')
        " max 200 lines , to '$' will be very slow
        let b:lines = getline( 1, 200 )
    endif

    let line = getline('.')
    let lnum = line('.')
    let start = col('.') - 1
    if a:findstart
        let b:comps = [ ]

        " XXX: read lines from current buffer
        " let b:lines   =
        let b:context  = getline('.')
        let b:lcontext = strpart(getline('.'),0,col('.')-1)
        let b:colpos   = col('.') - 1

        " let b:pcontext
        let b:paragraph_head = s:parseParagraphHead(lnum)

        let first_bwidx = -1

        for rule in s:rules
            let match = matchstr( b:lcontext , rule.backward )
            if strlen(match) > 0
                let bwidx   = strridx( b:lcontext , match )
            else
                " if backward regexp matched is empty, check if context regexp
                " is matched ? if yes, set bwidx to length, if not , set to -1
                if b:lcontext =~ rule.context
                    let bwidx = strlen(b:lcontext)
                else
                    let bwidx = -1
                endif
            endif

            " see if there is first matched index
            if first_bwidx != -1 && first_bwidx != bwidx
                continue
            endif

            if bwidx == -1
                continue
            endif

            " lefttext: context matched text
            " basetext: backward matched text
            let lefttext = strpart(b:lcontext,0,bwidx)
            let basetext = strpart(b:lcontext,bwidx)

            if ( has_key( rule ,'head')
                        \ && b:paragraph_head =~ rule.head
                        \ && lefttext =~ rule.context )
                        \ || ( ! has_key(rule,'head') && lefttext =~ rule.context  )

                if has_key( rule ,'contains' )
                    let l:text = rule.contains
                    let l:found = 0
                    " check content
                    for line in b:lines
                        if line =~ rule.contains
                            let l:found = 1
                            break
                        endif
                    endfor
                    if ! l:found
                        " next rule
                        continue
                    endif
                endif

                :DLOG 'use completion rule: ' . rule.name
                let l:comp = []
                if type(rule.comp) == type(function('tr'))
                    let l:comp = call(rule.comp, [basetext, lefttext])
                else type(rule.comp) == type([])
                    let l:comp = rule.comp
                end
                if empty(l:comp)
                    continue
                endif
                if type(l:comp) == type([])
                    cal extend(b:comps, l:comp)
                elseif type(l:comp) == type({})
                    call extend(b:comps, s:toCompHashList(l:comp))
                else
                    echoerr "Unknown completion handle type"
                endif

                if has_key(rule,'only') && rule.only == 1
                    return bwidx
                endif

                " save first backward index
                if first_bwidx == -1
                    let first_bwidx = bwidx
                endif
            endif
        endfor

        return first_bwidx
    else
        return b:comps
    endif
endfunction "}}}
" setlocal omnifunc=PerlComplete

" Util Function: {{{1
function! s:parseParagraphHead(fromLine) "{{{
    let lnum = a:fromLine
    let b:paragraph_head = getline(lnum)
    for nr in range(lnum-1,lnum-10,-1)
        let line = getline(nr)
        if line =~ '^\s*$' || line =~ '^\s*#'
            break
        endif
        let b:paragraph_head = line
    endfor
    return b:paragraph_head
endfunction "}}}

" toCompHashList: 
" a group list of word may share the same menu
" input: {word => [...], menu => m}
" output: [{word => w1, menu =>m}, {word => w1, menu =>m}, ..]
function! s:toCompHashList(dict) abort "{{{
    let l:words = get(a:dict, 'word', [])
    if empty(l:words)
        return []
    endif

    let l:menu = get(a:dict, 'menu', '')
    return map( copy(l:words) , '{ "word": v:val , "menu": "'. l:menu .'" }' )
endfunction "}}}

" Branch By If_perl:
if g:perlomni_enable_ifperl
    :PerlFile perlomni.pl
    call useperl#perlomni#hasperl#load()
else
    call useperl#perlomni#noperl#load()
endif


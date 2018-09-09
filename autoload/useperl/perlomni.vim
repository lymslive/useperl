" File: perlomni
" Author: lymslive
" Description: perl omni completion
"   based on: https://github.com/c9s/perlomni.vim
" Create: 2018-08-29
" Modify: 2018-08-29

" Note: file import relation
" perlomni <- rule <- (scanps | scanif <- ifperl) <- (cache & data)

" Package: 
let s:pack = {}
function! useperl#perlomni#pack() abort
    return s:pack
endfunction

" Configurations: {{{1
function! s:defopt(name,value)
    if !exists('g:{a:name}')
        let g:{a:name} = a:value
    endif
endfunction
cal s:defopt('perlomni_enable_ifperl', has('perl'))
cal s:defopt('perlomni_perl','perl')
cal s:defopt('perlomni_use_cache',1)
cal s:defopt('perlomni_cache_expiry',30)
cal s:defopt('perlomni_max_class_length',40)
cal s:defopt('perlomni_sort_class_by_lenth',0)
cal s:defopt('perlomni_use_perlinc',1)
" cal s:defopt('perlomni_show_hidden_func',0)
cal s:defopt('perlomni_export_functions','1')
cal s:defopt('perlomni_local_lib', ['.', 'lib'])

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
                elseif type(rule.comp) == type([])
                    let l:comp = rule.comp
                else
                    echoerr "Unknown completion handle type"
                end

                cal extend(b:comps, l:comp)
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

" Load Rules: {{{1
if g:perlomni_enable_ifperl
    :PerlUse Perlomni
    call useperl#perlomni#hasperl#load()
else
    call useperl#perlomni#noperl#load()
endif

" Rule View Command: {{{1
" ViewRule: 
function! s:ViewRule(...) abort "{{{
    if a:0 == 0
        for l:item in s:rules
            echo l:item.name
        endfor
    else
        if empty(a:1) || a:1 == '0'
            echo 'perlomni has rules: ' . len(s:rules)
        else
            for l:item in s:rules
                if l:item.name ==# a:1
                    echo 'rule: ' . string(l:item)
                    break
                endif
            endfor
        endif
    endif
endfunction "}}}
" ViewRuleComp: 
function! s:ViewRuleComp(A, L, P) abort "{{{
    let l:names = []
    for l:item in s:rules
        call add(l:names, l:item.name)
    endfor
    return join(l:names, "\n")
endfunction "}}}
command! -nargs=* -complete=custom,s:ViewRuleComp PerlOmniRuleView call s:ViewRule(<f-args>)

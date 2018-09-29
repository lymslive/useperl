" File: useperl
" Author: lymslive
" Description: auto plugin for perl
" Create: 2018-05-16
" Modify: 2018-05-16

let s:thisdir = expand('<sfile>:h')
function! useperl#plugin#dir() abort "{{{
    return s:thisdir
endfunction "}}}

" Perldoc:
execute 'source ' . s:thisdir . '/perldoc.vim'

if !exists(':DLOG')
    command -nargs=* DLOG "pass
endif
if !exists(':ELOG')
    command -nargs=* ELOG echoerr <args>
endif

if has('perl')
    call useperl#ifperl#load(s:thisdir)

    " add the ./lib sub-directory to @INC of perl
    let s:ifperl = useperl#ifperl#pack()
    call s:ifperl.uselib(s:thisdir . '/lib')
    call s:ifperl.require('ifperl.pl')

    command! -nargs=* PerlSearch call useperl#search#Commander(<q-args>)

    let g:ifperl_log_on = -1
endif

" Perlomni:
execute 'source ' . s:thisdir . '/perlomni.vim'

" support neocomplete
if exists('g:neocomplete#sources#omni#input_patterns')
    let g:neocomplete#sources#omni#input_patterns.perl = '[^. \t]->\%(\h\w*\)\?\|\h\w*::\%(\h\w*\)\?\|[&$%@]{\?\%(\h\w*\)\?'
endif

" load: 
function! useperl#plugin#load() abort "{{{
    return 1
endfunction "}}}


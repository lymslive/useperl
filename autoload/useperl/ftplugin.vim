" File: ftplugin
" Author: lymslive
" Description: ftplugin module for useperl plugin
" Create: 2018-09-27
" Modify: 2018-09-27

" Func: s:ft_perl 
function! s:ft_perl() abort "{{{
    if get(b:, 'useperl_ftplugin_did', 0)
        return
    endif
    let b:useperl_ftplugin_did = 1

    " silent! nmap <buffer> <unique> K <Plug>(perldoc)
    nnoremap <silent> <buffer> K :<C-u>Perldoc<CR>

    setlocal omnifunc=PerlComplete
    if exists('g:neocomplete#sources#omni#input_patterns')
        if get(g:neocomplete#sources#omni#input_patterns, 'perl', '') == ''
            let g:neocomplete#sources#omni#input_patterns.perl = '[^. \t]->\%(\h\w*\)\?\|\h\w*::\%(\h\w*\)\?\|[&$%@]{\?\%(\h\w*\)\?'
        endif
    endif
endfunction "}}}

function! useperl#ftplugin#load(...) abort "{{{
    if a:0 == 0 || a:1 ==? 'perl'
        return s:ft_perl()
    else
        echoerr 'this plugin maybe only useful for perl'
        return
    endif
endfunction "}}}


setlocal omnifunc=PerlComplete
if exists('g:neocomplete#sources#omni#input_patterns')
    if get(g:neocomplete#sources#omni#input_patterns, 'perl', '') == ''
        let g:neocomplete#sources#omni#input_patterns.perl = '[^. \t]->\%(\h\w*\)\?\|\h\w*::\%(\h\w*\)\?\|[&$%@]{\?\%(\h\w*\)\?'
    endif
endif

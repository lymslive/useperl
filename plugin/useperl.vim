if !exists('g:loaded_useperl')
    " call useperl#plugin#load()
    execute 'source ' expand('<sfile>:p:h:h') . '/autoload/useperl/plugin.vim'
    " echo expand('<sfile>:p:h:h') . '/autoload/useperl/plugin.vim'
endif

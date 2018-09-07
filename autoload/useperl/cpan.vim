" File: cpan
" Author: lymslive
" Description: utils for cpan
" Create: 2018-09-07
" Modify: 2018-09-07

" CPAN PERL CLASS LIST UTILS: {{{
" CPANParseSourceList {{{
" cat 02packages.details.txt.gz | gzip -dc | grep -Ev '^[A-Za-z0-9-[]+: ' | cut -d" " -f1
function! CPANParseSourceList(file)
    if ! exists('g:cpan_mod_cachef')
        let g:cpan_mod_cachef = expand('~/.vim-cpan-module-cache')
    endif
    if !filereadable(g:cpan_mod_cachef) || getftime(g:cpan_mod_cachef) < getftime(a:file)
        let args = ['cat', a:file, '|', 'gzip', '-dc', '|',
                    \ 'grep', '-Ev', '^[A-Za-z0-9-]+: ', '|', 'cut', '-d" "', '-f1']
        let data = call(function("s:system"), args)
        cal writefile(split(data, "\n"), g:cpan_mod_cachef)
    endif
    return readfile( g:cpan_mod_cachef )
endfunction
" }}}
" CPANSourceLists {{{
" XXX: copied from cpan.vim plugin , should be reused.
" fetch source list from remote
function! CPANSourceLists()
    let paths = [
                \expand('~/.cpanplus/02packages.details.txt.gz'),
                \expand('~/.cpan/sources/modules/02packages.details.txt.gz')
                \]
    if exists('g:cpan_user_defined_sources')
        call extend( paths , g:cpan_user_defined_sources )
    endif

    for f in paths
        if filereadable( f )
            return f
        endif
    endfor

    " not found
    echo "CPAN source list not found."
    let f = expand('~/.cpan/sources/modules/02packages.details.txt.gz')
    cal mkdir( expand('~/.cpan/sources/modules'), 'p')

    echo "Downloading CPAN source list."
    if executable('curl')
        exec '!curl http://cpan.nctu.edu.tw/modules/02packages.details.txt.gz -o ' . s:ShellQuote(f)
        return f
    elseif executable('wget')
        exec '!wget http://cpan.nctu.edu.tw/modules/02packages.details.txt.gz -O ' . s:ShellQuote(f)
        return f
    endif
    echoerr "You don't have curl or wget to download the package list."
    return
endfunction
" let sourcefile = CPANSourceLists()
" let classnames = CPANParseSourceList( sourcefile )
" echo remove(classnames,10)
" }}}
" }}}


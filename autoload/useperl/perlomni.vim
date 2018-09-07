" File: perlomni
" Author: lymslive
" Description: perl omni completion
"   based on: https://github.com/c9s/perlomni.vim
" Create: 2018-08-29
" Modify: 2018-08-29

let s:debug_flag = 0
function! s:debug(name,var)
    if s:debug_flag
        echo a:name . ":" . a:var
        sleep 1
    endif
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

if g:perlomni_enable_ifperl
    :PerlFile perlomni.pl
    let s:ifperl = useperl#ifperl#pack()
endif

" Wrapped System Function: {{{1
function! s:system(...)
    let cmd = ''
    if has('win32')
        let ext = toupper(substitute(a:1, '^.*\.', '.', ''))
        if !len(filter(split($PATHEXT, ';'), 'toupper(v:val) == ext'))
            if ext == '.PL' && executable(g:perlomni_perl)
                let cmd = g:perlomni_perl
            elseif ext == '.PY' && executable('python')
                let cmd = 'python'
            elseif ext == '.RB' && executable('ruby')
                let cmd = 'ruby'
            endif
        endif
        for a in a:000
            if len(cmd) | let cmd .= ' ' | endif
            if substitute(substitute(a, '\\.', '', 'g'), '\([''"]\).*\1', '', 'g') =~ ' ' || (a != '|' && a =~ '|') || a =~ '[()]' | let a = '"' . substitute(a, '"', '"""', 'g') . '"' | endif
            let cmd .= a
        endfor
    else
        for a in a:000
            if len(cmd) | let cmd .= ' ' | endif
            if substitute(substitute(a, '\\.', '', 'g'), '\([''"]\).*\1', '', 'g') =~ ' ' || (a != '|' && a =~ '|') || a =~ '[()]' | let a = shellescape(a) | endif
            let cmd .= a
        endfor
    endif
    return system(cmd)
endfunction

function! s:runPerlEval(mtext,code)
    if g:perlomni_enable_ifperl
        return s:ifperl.execute(a:code, a:mtext)
    endif
    let cmd = g:perlomni_perl . ' -M' . a:mtext . ' -e "' . escape(a:code,'"') . '"'
    return system(cmd)
endfunction


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

function! s:SetCacheNS(ns,key,value) "{{{
    if ! exists('g:perlomni_cache')
        let g:perlomni_cache = { }
    endif
    let key = a:ns . "_" . a:key
    let g:perlomni_cache[ key ] = a:value
    return a:value
endfunction "}}}
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

" COMPLETION PARSE UTILS: {{{1

" Trival Util Functions: {{{

function! s:Quote(list)
    return map(copy(a:list), '"''".v:val."''"' )
endfunction

function! s:RegExpFilter(list,pattern)
    return filter(copy(a:list),"v:val =~ a:pattern")
endfunction

function! s:StringFilter(list,string)
    return filter(copy(a:list),"stridx(v:val,a:string) == 0 && v:val != a:string" )
endfunction

function! s:ShellQuote(s)
    return &shellxquote == '"' ? "'".a:s."'" : '"'.a:s.'"'
endfunction

" util function for building completion hashlist
function! s:toCompHashList(list,menu)
    return map( a:list , '{ "word": v:val , "menu": "'. a:menu .'" }' )
endfunction

" tmpfile: save some line in tmpfile, and return the file name 
function! s:tmpfile(lines) abort "{{{
    let l:buffile = tempname()
    cal writefile(a:lines, l:buffile)
    return l:buffile
endfunction

" }}}

let s:perlreg = {}
let s:perlreg.BaseClass = '^(?:use\s+(?:base|parent)\s+|extends\s+)(.*);'
let s:perlreg.Function = '^\s*(?:sub|has)\s+(\w+)'
let s:perlreg.QString = '[''](.*?)(?<!\\)['']'
let s:perlreg.QQString = '["](.*?)(?<!\\)["]'

let s:vimreg = {}
let s:vimreg.Module = '[a-zA-Z][a-zA-Z0-9:]\+'

" BASE CLASS UTILS: {{{
function! s:baseClassFromFile(file)
    let l:cache = s:GetCacheNS('clsf_bcls',a:file)
    if type(l:cache) != type(0)
        return l:cache
    endif
    if g:perlomni_enable_ifperl
        let list = split(s:ifperl.call('perlomni::GrepPattern', a:file, s:perlreg.BaseClass), "\n")
    else
        let list = split(s:system(s:vimbin.'grep-pattern.pl', a:file, s:perlreg.BaseClass),"\n")
    endif
    let classes = [ ]
    for i in range(0,len(list)-1)
        let list[i] = substitute(list[i],'^\(qw[(''"\[]\|(\|[''"]\)\s*','','')
        let list[i] = substitute(list[i],'[)''"]$','','')
        let list[i] = substitute(list[i],'[,''"]',' ','g')
        cal extend( classes , split(list[i],'\s\+'))
    endfor
    return s:SetCacheNS('clsf_bcls',a:file,classes)
endfunction
" echo s:baseClassFromFile(expand('%'))

function! s:findBaseClass(class)
    let file = s:locateClassFile(a:class)
    if file == ''
        return []
    endif
    return s:baseClassFromFile(file)
endfunction
" echo s:findBaseClass( 'Jifty::Record' )

function! s:findCurrentClassBaseClass()
    let all_mods = [ ]
    for i in range( line('.') , 1 , -1 )
        let line = getline(i)
        if line =~ '^package\s\+'
            break
        elseif line =~ '^\(use\s\+\(base\|parent\)\|extends\)\s\+'
            let args =  matchstr( line ,
                        \ '\(^\(use\s\+\(base\|parent\)\|extends\)\s\+\(qw\)\=[''"(\[]\)\@<=\_.*\([\)\]''"]\s*;\)\@=' )
            let args = substitute( args  , '\_[ ]\+' , ' ' , 'g' )
            let mods = split(  args , '\s' )
            cal extend( all_mods , mods )
        endif
    endfor
    return all_mods
endfunction

function! s:locateClassFile(class)
    let l:cache = s:GetCacheNS('clsfpath',a:class)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let paths = map(split(&path, '\\\@<![, ]'), 'substitute(v:val, ''\\\([, ]\)'', ''\1'', ''g'')')
    if g:perlomni_use_perlinc || &filetype != 'perl'
        if g:perlomni_enable_ifperl
            let paths = split(s:ifperl.call('GotIncPath'), ',')
        else
            let paths = split(s:system(g:perlomni_perl, '-e', 'print join(",",@INC)') ,',')
        endif
    endif

    let filepath = substitute(a:class,'::','/','g') . '.pm'
    cal insert(paths,'lib')
    for path in paths
        if filereadable( path . '/' . filepath )
            return s:SetCacheNS('clsfpath',a:class,path .'/' . filepath)
        endif
    endfor
    return ''
endfunction
" echo s:locateClassFile('Jifty::DBI')
" echo s:locateClassFile('No')
" }}}

function! s:grepBufferList(pattern) "{{{
    redir => bufferlist
    silent buffers
    redir END
    let lines = split(bufferlist,"\n")
    let files = [ ]
    for line in lines
        let buffile = matchstr( line , '\("\)\@<=\S\+\("\)\@=' )
        if buffile =~ a:pattern
            cal add(files,expand(buffile))
        endif
    endfor
    return files
endfunction "}}}
" echo s:grepBufferList('\.pm$')

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

" SCANNING FUNCTIONS: {{{

" scan exported functions from a module.
function! s:scanModuleExportFunctions(class)
    let l:cache = s:GetCacheNS('mef',a:class)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let funcs = []

    " XXX: TOO SLOW, CACHE TO FILE!!!!
    if g:perlomni_export_functions
        let output = s:runPerlEval( a:class , printf( 'print join " ",@%s::EXPORT_OK' , a:class ))
        cal extend( funcs , split( output ) )
        let output = s:runPerlEval( a:class , printf( 'print join " ",@%s::EXPORT' , a:class ))
        cal extend( funcs , split( output ) )
        " echo [a:class,output]
    endif
    return s:SetCacheNS('mef',a:class, s:toCompHashList(funcs, a:class))
endfunction
" echo s:scanModuleExportFunctions( 'List::MoreUtils' )
" sleep 1

" Scan export functions in current buffer
" Return functions
function! s:scanCurrentExportFunction()
    let l:cache = s:GetCacheNS('cbexf', bufname('%'))
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline( 1 , '$' )
    cal filter(  lines , 'v:val =~ ''^\s*\(use\|require\)\s''')
    let funcs = [ ]
    for line in lines
        let m = matchstr( line , '\(^use\s\+\)\@<=' . s:vimreg.Module )
        if strlen(m) > 0
            cal extend(funcs ,s:scanModuleExportFunctions(m))
        endif
    endfor
    return s:SetCacheNS('cbexf',bufname('%'),funcs)
endfunction
" echo s:scanCurrentExportFunction()
" sleep 1

function! s:scanClass(path) " {{{
    let l:cache = s:GetCacheNS('classpath', a:path)
    if type(l:cache) != type(0)
        return l:cache
    endif
    if ! isdirectory(a:path)
        return [ ]
    endif
    let l:files = split(glob(a:path . '/**'))
    cal filter(l:files, 'v:val =~ "\.pm$"')
    cal map(l:files, 'strpart(v:val,strlen(a:path)+1,strlen(v:val)-strlen(a:path)-4)')
    cal map(l:files, 'substitute(v:val,''/'',"::","g")')
    return s:SetCacheNS('classpath',a:path,l:files)
endfunction
" echo s:scanClass(expand('~/aiink/aiink/lib'))
" }}}
function! s:scanObjectVariableLines(lines) " {{{
    if g:perlomni_enable_ifperl
        let varlist = split(s:ifperl.deal_list(a:lines, 'perlomni::DLGrepObjval'),"\n")
    else
        let varlist = split(s:system(s:vimbin.'grep-objvar.pl', s:tmpfile(a:lines)),"\n")
    endif
    let b:objvarMapping = { }
    for item in varlist
        let [varname,classname] = split(item)
        if exists('b:objvarMapping[varname]')
            cal add( b:objvarMapping[ varname ] , classname )
        else
            let b:objvarMapping[ varname ] = [ classname ]
        endif
    endfor
    return b:objvarMapping
endfunction
" echo s:scanObjectVariableLines([])
" }}}

function! s:scanObjectVariableFile(file)
    if g:perlomni_enable_ifperl
        let list = split(s:ifperl.call('perlomni::GrepObjval', expand(a:file)),"n")
    else
        let list = split(s:system(s:vimbin.'grep-objvar.pl', expand(a:file)),"\n")
    endif
    let b:objvarMapping = { }
    for item in list
        let [varname,classname] = split(item)
        if exists('b:objvarMapping[varname]')
            cal add( b:objvarMapping[ varname ] , classname )
        else
            let b:objvarMapping[ varname ] = [ classname ]
        endif
    endfor
    return b:objvarMapping
endfunction
" echo s:scanObjectVariableFile( expand('~/git/bps/jifty-dbi/lib/Jifty/DBI/Collection.pm') )

if g:perlomni_enable_ifperl
function! s:scanVariable(lines)
    return uniq(sort(split(s:ifperl.deal_list(a:lines, 'perlomni::DLGrepPattern', '\$(\w+)'),"\n")))
endfunction
function! s:scanArrayVariable(lines)
    return uniq(sort(split(s:ifperl.deal_list(a:lines, 'perlomni::DLGrepPattern', '@(\w+)'), "\n")))
endfunction
function! s:scanHashVariable(lines)
    return uniq(sort(split(s:ifperl.deal_list(a:lines, 'perlomni::DLGrepPattern', '%(\w+)'), "\n")))
endfunction
function! s:scanQString(lines)
    return split(s:ifperl.deal_list(a:lines, 'perlomni::DLGrepPattern', s:perlreg.QString), "\n")
endfunction
function! s:scanQQString(lines)
    return split(s:ifperl.deal_list(a:lines, 'perlomni::DLGrepPattern', s:perlreg.QQString), "\n")
endfunction
function! s:scanFunctionFromList(lines)
    return uniq(sort(split(s:ifperl.deal_list(a:lines, 'perlomni::DLGrepPattern', s:perlreg.Function), "\n")))
endfunction

else
function! s:scanVariable(lines)
    return split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(a:lines), '\$(\w+)', '|', 'sort', '|', 'uniq'),"\n")
endfunction
function! s:scanArrayVariable(lines)
    return split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(a:lines), '@(\w+)', '|', 'sort', '|', 'uniq'),"\n")
endfunction
function! s:scanHashVariable(lines)
    return split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(a:lines), '%(\w+)', '|', 'sort', '|', 'uniq'),"\n")
endfunction
function! s:scanQString(lines)
    return split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(a:lines), s:perlreg.QString) ,"\n")
endfunction
function! s:scanQQString(lines)
    return split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(a:lines), s:perlreg.QQString),"\n")
endfunction
function! s:scanFunctionFromList(lines)
    return split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(a:lines), s:perlreg.Function, '|', 'sort', '|', 'uniq'),"\n")
endfunction
endif

function! s:scanFunctionFromSingleClassFile(file)
    if g:perlomni_enable_ifperl
        return uniq(sort(split(s:ifperl.call('perlomni::GrepPattern', a:file, s:perlreg.Function), "\n")))
    else
        return split(s:system(s:vimbin.'grep-pattern.pl', a:file, s:perlreg.Function, '|', 'sort', '|', 'uniq'),"\n")
    endif
endfunction

function! s:scanFunctionFromClass(class)
    let classfile = s:locateClassFile(a:class)
    return classfile == '' ? [ ] :
                \ extend( s:scanFunctionFromSingleClassFile(classfile),
                \ s:scanFunctionFromBaseClassFile(classfile) )
endfunction
" echo s:scanFunctionFromClass('Jifty::DBI::Record')
" echo s:scanFunctionFromClass('CGI')
" sleep 1

" scan functions from file and parent classes.
function! s:scanFunctionFromBaseClassFile(file)
    if ! filereadable( a:file )
        return [ ]
    endif

    let l:funcs = s:scanFunctionFromSingleClassFile(a:file)
    "     echo 'sub:' . a:file
    let classes = s:baseClassFromFile(a:file)
    for cls in classes
        unlet! l:cache
        let l:cache = s:GetCacheNS('classfile_funcs',cls)
        if type(l:cache) != type(0)
            cal extend(l:funcs,l:cache)
            continue
        endif

        let clsfile = s:locateClassFile(cls)
        if clsfile != ''
            let bfuncs = s:scanFunctionFromBaseClassFile( clsfile )
            cal s:SetCacheNS('classfile_funcs',cls,bfuncs)
            cal extend( l:funcs , bfuncs )
        endif
    endfor
    return l:funcs
endfunction
" let fs = s:scanFunctionFromBaseClassFile(expand('%'))
" echo len(fs)

" }}}

" COMPLETION METHODS: {{{1
let s:ComniData = useperl#perlomni#data#struct()
" DBI METHOD COMPLETION: {{{
" XXX: provide a dictinoary loader
function! s:CompDBIxMethod(base,context)
    return s:StringFilter([
                \ "table" , "table_class" , "add_columns" ,
                \ "set_primary_key" , "has_many" ,
                \ "many_to_many" , "belongs_to" , "add_columns" ,
                \ "might_have" ,
                \ "has_one",
                \ "add_unique_constraint",
                \ "resultset_class",
                \ "load_namespaces",
                \ "load_components",
                \ "load_classes",
                \ "resultset_attributes" ,
                \ "result_source_instance" ,
                \ "mk_group_accessors",
                \ "storage"
                \ ],a:base)
endfunction

function! s:scanDBIxResultClasses()
    let path = 'lib'
    let l:cache = s:GetCacheNS('dbix_c',path)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let pms = split(system('find ' . path . ' -iname "*.pm" | grep Result'),"\n")
    cal map( pms, 'substitute(v:val,''^.*lib/\?'',"","")')
    cal map( pms, 'substitute(v:val,"\\.pm$","","")' )
    cal map( pms, 'substitute(v:val,"/","::","g")' )

    return s:SetCacheNS('dbix_c',path,pms)
endfunction

function! s:getResultClassName( classes )
    let classes = copy(a:classes)
    cal map( classes , "substitute(v:val,'^.*::','','')" )
    return classes
endfunction

function! s:CompDBIxResultClassName(base,context)
    return s:StringFilter( s:getResultClassName(   s:scanDBIxResultClasses()  )  ,a:base)
endfunction

function! s:CompExportFunction(base,context)
    let m = matchstr( a:context , '\(^use\s\+\)\@<=' . s:vimreg.Module )
    let l:funcs = s:scanModuleExportFunctions(m)
    let l:words = filter(copy(l:funcs), 'v:val.word =~ a:base')
    return l:words
endfunction

function! s:CompModuleInstallExport(base,context)
    let words = s:ComniData.p5_mi_export
    return filter( copy(words) , 'v:val.word =~ a:base' )
endfunction
" }}}
" SIMPLE MOOSE COMPLETION: {{{
function! s:CompMooseIs(base,context)
    return s:Quote(['rw', 'ro', 'wo'])
endfunction

function! s:CompMooseIsa(base,context)
    let l:comps = ['Int', 'Str', 'HashRef', 'HashRef[', 'Num', 'ArrayRef']
    let base = substitute(a:base,'^[''"]','','')
    cal extend(l:comps, s:CompClassName(base,a:context))
    return s:Quote(s:StringFilter(l:comps, base))
endfunction

function! s:CompMooseAttribute(base,context)
    let values = [ 'default' , 'is' , 'isa' ,
                \ 'label' , 'predicate', 'metaclass', 'label',
                \ 'expires_after',
                \ 'refresh_with' , 'required' , 'coerce' , 'does' , 'required',
                \ 'weak_ref' , 'lazy' , 'auto_deref' , 'trigger',
                \ 'handles' , 'traits' , 'builder' , 'clearer',
                \ 'predicate' , 'lazy_build', 'initializer', 'documentation' ]
    cal map(values,'v:val . " => "')
    return s:StringFilter(values,a:base)
endfunction

function! s:CompMooseRoleAttr(base,context)
    let attrs = [ 'alias', 'excludes' ]
    return s:StringFilter(attrs,a:base)
endfunction
function! s:CompMooseStatement(base,context)
    let sts = [
                \'extends' , 'after' , 'before', 'has' ,
                \'requires' , 'with' , 'override' , 'method',
                \'super', 'around', 'inner', 'augment', 'confess' , 'blessed' ]
    return s:StringFilter(sts,a:base)
endfunction
" }}}
" PERL CORE OMNI COMPLETION: {{{

function! s:CompVariable(base,context)
    let l:cache = s:GetCacheNS('variables',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline(1,'$')
    let variables = s:scanVariable(lines)
    cal extend( variables , s:scanArrayVariable(lines))
    cal extend( variables , s:scanHashVariable(lines))
    let result = s:StringFilter(variables, a:base)
    return s:SetCacheNS('variables',a:base,result)
endfunction

function! s:CompArrayVariable(base,context)
    let l:cache = s:GetCacheNS('arrayvar',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline(1,'$')
    let variables = s:scanArrayVariable(lines)
    let result = s:StringFilter(variables, a:base)
    return s:SetCacheNS('arrayvar',a:base,result)
endfunction

function! s:CompHashVariable(base,context)
    let l:cache = s:GetCacheNS('hashvar',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif
    let lines = getline(1,'$')
    let variables = s:scanHashVariable(lines)
    let result = s:StringFilter(variables, a:base)
    return s:SetCacheNS('hashvar',a:base,result)
endfunction

" perl builtin functions
function! s:CompFunction(base,context)
    let efuncs = s:scanCurrentExportFunction()
    let flist = copy(s:ComniData.p5bfunctions)
    cal extend(flist,efuncs)
    return filter(flist,'v:val.word =~ "^".a:base')
endfunction

function! s:CompCurrentBaseFunction(base,context)
    let all_mods = s:findCurrentClassBaseClass()
    let funcs = [ ]
    for mod in all_mods
        let sublist = s:scanFunctionFromClass(mod)
        cal extend(funcs,sublist)
    endfor
    return funcs
endfunction
" echo s:CompCurrentBaseFunction('','$self->')
" sleep 1

function! s:CompBufferFunction(base,context)
    let l:cache = s:GetCacheNS('buf_func',a:base.expand('%'))
    if type(l:cache) != type(0)
        return l:cache
    endif

    let l:cache2 = s:GetCacheNS('buf_func_all',expand('%'))
    if type(l:cache2) != type(0)
        let funclist = l:cache2
    else
        let lines = getline(1,'$')
        let funclist = s:SetCacheNS('buf_func_all',expand('%'),s:scanFunctionFromList(lines))
    endif
    let result = s:StringFilter(funclist, a:base)
    return s:SetCacheNS('buf_func',a:base.expand('%'),result)
endfunction

function! s:CompClassFunction(base,context)
    let class = matchstr(a:context,'[a-zA-Z0-9:]\+\(->\)\@=')
    let l:cache = s:GetCacheNS('classfunc',class.'_'.a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let l:cache2 = s:GetCacheNS('class_func_all',class)
    let funclist = type(l:cache2) != type(0) ? l:cache2 : s:SetCacheNS('class_func_all',class,s:scanFunctionFromClass(class))

    let result = s:StringFilter(funclist, a:base)
    let funclist = s:SetCacheNS('classfunc',class.'_'.a:base,result)
    if g:perlomni_show_hidden_func == 0
        call filter(funclist, 'v:val !~ "^_"')
    endif
    return funclist
endfunction

function! s:CompObjectMethod(base,context)
    let objvarname = matchstr(a:context,'\$\w\+\(->$\)\@=')
    let l:cache = s:GetCacheNS('objectMethod',objvarname.'_'.a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    " Scan from current buffer
    " echo 'scan from current buffer' | sleep 100ms
    if ! exists('b:objvarMapping')
                \ || ! has_key(b:objvarMapping,objvarname)
        let minnr = line('.') - 10
        let minnr = minnr < 1 ? 1 : minnr
        let lines = getline( minnr , line('.') )
        cal s:scanObjectVariableLines(lines)
    endif

    " Scan from other buffers
    " echo 'scan from other buffer' | sleep 100ms
    if ! has_key(b:objvarMapping,objvarname)
        let bufferfiles = s:grepBufferList('\.p[ml]$')
        for file in bufferfiles
            cal s:scanObjectVariableFile( file )
        endfor
    endif

    " echo 'scan functions' | sleep 100ms
    let funclist = [ ]
    if has_key(b:objvarMapping,objvarname)
        let classes = b:objvarMapping[ objvarname ]
        for cls in classes
            cal extend(funclist,s:scanFunctionFromClass( cls ))
        endfor
        let result = s:StringFilter(funclist, a:base)
        let funclist = s:SetCacheNS('objectMethod',objvarname.'_'.a:base,result)
    endif
    if g:perlomni_show_hidden_func == 0
        call filter(funclist, 'v:val !~ "^_"')
    endif
    return funclist
endfunction
" let b:objvarMapping = {  }
" let b:objvarMapping[ '$cgi'  ] = ['CGI']
" echo s:CompObjectMethod( '' , '$cgi->' )
" sleep 1

function! s:CompClassName(base,context)
    let cache = s:GetCacheNS('class',a:base)
    if type(cache) != type(0)
        return cache
    endif

    " XXX: prevent waiting too long
    if strlen(a:base) == 0
        return [ ]
    endif

    if exists('g:cpan_mod_cache')
        let classnames = g:cpan_mod_cache
    else
        let sourcefile = CPANSourceLists()
        let classnames = CPANParseSourceList( sourcefile )
        let g:cpan_mod_cache = classnames
    endif
    cal extend(classnames, s:scanClass('lib'))

    let result = s:StringFilter(classnames,a:base)

    if len(result) > g:perlomni_max_class_length
        cal remove(result, g:perlomni_max_class_length, len(result)-1)
    endif
    if g:perlomni_sort_class_by_lenth
        cal sort(result,'s:SortByLength')
    else
        cal sort(result)
    endif
    return s:SetCacheNS('class',a:base,result)
endfunction
" echo s:CompClassName('Moose::','')

function! s:SortByLength(i1, i2)
    return strlen(a:i1) == strlen(a:i2) ? 0 : strlen(a:i1) > strlen(a:i2) ? 1 : -1
endfunction


function! s:CompUnderscoreTokens(base,context)
    return s:StringFilter( [ 'PACKAGE__' , 'END__' , 'DATA__' , 'LINE__' , 'FILE__' ] , a:base )
endfunction

function! s:CompPodSections(base,context)
    return s:StringFilter( [ 'NAME' , 'SYNOPSIS' , 'AUTHOR' , 'DESCRIPTION' , 'FUNCTIONS' ,
                \ 'USAGE' , 'OPTIONS' , 'BUG REPORT' , 'DEVELOPMENT' , 'NOTES' , 'ABOUT' , 'REFERENCES' ] , a:base )
endfunction

function! s:CompPodHeaders(base,context)
    return s:StringFilter(
                \ [ 'head1' , 'head2' , 'head3' , 'begin' , 'end',
                \   'encoding' , 'cut' , 'pod' , 'over' ,
                \   'item' , 'for' , 'back' ] , a:base )
endfunction

" echo s:CompPodHeaders('h','')

function! s:CompQString(base,context)
    let lines = getline(1,'$')
    let strings = s:scanQString( lines )
    return s:StringFilter(strings,a:base)
endfunction

" }}}

" COMPLETION RULES: {{{1
" rules have head should be first matched , because of we get first backward position.
"

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

" MODULE-INSTALL FUNCTIONS ================================={{{
cal s:rule({ 'name' : 'ModuleInstallExport',
    \'contains'  :  'Module::Install',
    \'backward'  :  '\w*$',
    \'context'   :  '^$',
    \'comp'      :  function('s:CompModuleInstallExport') })

cal s:rule({ 'name' : 'ModuleInstall',
    \'context': '^\(requires\|build_requires\|test_requires\)\s',
    \'backward': '[a-zA-Z0-9:]*$',
    \'comp': function('s:CompClassName') })

" }}}
" UNDERSCORES =================================="{{{
cal s:rule({ 'name' : 'UnderscoreTokens',
    \'context': '__$',
    \'backward': '[A-Z]*$',
    \'comp': function('s:CompUnderscoreTokens') })
"}}}

" DBIX::CLASS::CORE COMPLETION ======================================"{{{
"
"   use contains to check file content, do complete dbix methods if and only
"   if there is a DBIx::Class::Core
"
" because there is a rule take 'only' attribute,
" so the rest rules willn't be check.
" for the reason , put the dbix completion rule before them.
" will take a look later ... (I hope)
cal s:rule({ 'name' : 'DBIx::Method',
    \'context': '^__PACKAGE__->$',
    \'contains': 'DBIx::Class::Core',
    \'backward': '\w*$',
    \'comp':    function('s:CompDBIxMethod')
    \})

cal s:rule({ 'name' : 'DBIx::ResultClass',
    \'only': 1,
    \'context': '->resultset(\s*[''"]',
    \'backward': '\w*$',
    \'comp':  function('s:CompDBIxResultClassName') } )

"}}}

" Moose Completion Rules: {{{
cal s:rule({ 'name' : 'Moose::Is',
    \'only':1,
    \'head': '^has\s\+\w\+' ,
    \'context': '\s\+is\s*=>\s*$',
    \'backward': '[''"]\?\w*$' ,
    \'comp': function('s:CompMooseIs') } )

cal s:rule({ 'name' : 'Moose::Isa',
    \'only':1,
    \'head': '^has\s\+\w\+' ,
    \'context': '\s\+\(isa\|does\)\s*=>\s*$' ,
    \'backward': '[''"]\?\S*$' ,
    \'comp': function('s:CompMooseIsa') } )

cal s:rule({ 'name' : 'Moose::BufferFunction',
    \'only':1, 
    \'head': '^has\s\+\w\+',
    \'context': '\s\+\(reader\|writer\|clearer\|predicate\|builder\)\s*=>\s*[''"]$' ,
    \'backward': '\w*$',
    \'comp': function('s:CompBufferFunction') })

cal s:rule({ 'name' : 'Moose::Attribute',
    \'only':1,
    \'head': '^has\s\+\w\+',
    \'context': '^\s*$',
    \'backward': '\w*$',
    \'comp': function('s:CompMooseAttribute') } )

cal s:rule({ 'name' : 'Moose::RoleAttr',
    \'only':1,
    \'head': '^with\s\+',
    \'context': '^\s*-$',
    \'backward': '\w\+$',
    \'comp': function('s:CompMooseRoleAttr') } )

cal s:rule({ 'name' : 'Moose::Statement',
    \'context': '^\s*$',
    \'backward': '\w\+$',
    \'comp':function('s:CompMooseStatement')})

" }}}
" Core Completion Rules: {{{
cal s:rule({ 'name' : 'Pod::Headers',
    \'only':1, 
    \'context': '^=$',
    \'backward': '\w*$',
    \'comp': function('s:CompPodHeaders') })

cal s:rule({ 'name' : 'Pod::Sections',
    \'only':1,
    \'context': '^=\w\+\s',
    \'backward': '\w*$',
    \'comp': function('s:CompPodSections') })

" export function completion
cal s:rule({ 'name' : 'ExportFunction',
    \'only': 1,
    \'context': '^use\s\+[a-zA-Z0-9:]\+\s\+qw',
    \'backward': '\w*$',
    \'comp': function('s:CompExportFunction') })

" class name completion
"  matches:
"     new [ClassName]
"     use [ClassName]
"     use base qw(ClassName ...
"     use base 'ClassName
cal s:rule({ 'name' : 'ClassName',
    \'only':1,
    \'context': '\<\(new\|use\)\s\+\(\(base\|parent\)\s\+\(qw\)\?[''"(/]\)\?$',
    \'backward': '\<[A-Z][A-Za-z0-9_:]*$',
    \'comp': function('s:CompClassName') } )


cal s:rule({ 'name' : 'ClassName',
    \'only':1,
    \'context': '^extends\s\+[''"]$',
    \'backward': '\<\u[A-Za-z0-9_:]*$',
    \'comp': function('s:CompClassName') } )

cal s:rule({ 'name' : 'BaseFunction',
    \'context': '^\s*\(sub\|method\)\s\+',
    \'backward': '\<\w\+$' ,
    \'only':1 ,
    \'comp': function('s:CompCurrentBaseFunction') })

cal s:rule({ 'name' : 'ObjectSelf',
    \'only':1,
    \'context': '^\s*my\s\+\$self' ,
    \'backward': '\s*=\s\+shift;',
    \'comp': [ ' = shift;' ] })

" variable completion
cal s:rule({ 'name' : 'Variable',
    \'only':1,
    \'context': '\s*\$$',
    \'backward': '\<\U\w*$',
    \'comp': function('s:CompVariable') })

cal s:rule({ 'name' : 'ArrayVariable',
    \'only':1,
    \'context': '@$',
    \'backward': '\<\U\w\+$',
    \'comp': function('s:CompArrayVariable') })

cal s:rule({ 'name' : 'HashVariable',
    \'only':1,
    \'context': '%$',
    \'backward': '\<\U\w\+$',
    \'comp': function('s:CompHashVariable') })

cal s:rule({ 'name' : 'BufferFunction',
    \'only':1,
    \'context': '&$',
    \'backward': '\<\U\w\+$',
    \'comp': function('s:CompBufferFunction') })


" function completion
cal s:rule({ 'name' : 'Function',
    \'context': '\(->\|\$\)\@<!$',
    \'backward': '\<\w\+$' ,
    \'comp': function('s:CompFunction') })

cal s:rule( 'name' : 'BufferMethod',
    \{'context': '\$\(self\|class\)->$',
    \'backward': '\<\w\+$' ,
    \'only':1 ,
    \'comp': function('s:CompBufferFunction') })

cal s:rule({ 'name' : 'ObjectMethod',
    \'context': '\$\w\+->$',
    \'backward': '\<\w\+$',
    \'comp': function('s:CompObjectMethod') })

cal s:rule({ 'name' : 'ClassFunction',
    \'context': '\<[a-zA-Z0-9:]\+->$',
    \'backward': '\w*$',
    \'comp': function('s:CompClassFunction') })

cal s:rule({ 'name' : 'ClassName',
    \'context': '$' ,
    \'backward': '\<\u\w*::[a-zA-Z0-9:]*$',
    \'comp': function('s:CompClassName') } )

" string completion
" cal s:rule({'context': '\s''', 'backward': '\_[^'']*$' , 'comp': function('s:CompQString') })

" }}}

" Public API: {{{1

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
                if type(rule.comp) == type(function('tr'))
                    cal extend(b:comps, call( rule.comp, [basetext,lefttext] ) )
                elseif type(rule.comp) == type([])
                    cal extend(b:comps,rule.comp)
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
endfunction
" setlocal omnifunc=PerlComplete

" pack: 
function! useperl#perlomni#pack() abort "{{{
    if !exists('s:pack')
        let s:pack = {}
        let s:pack.AddPerlOmniRule = function('s:rule')
    endif
    return s:pack
endfunction


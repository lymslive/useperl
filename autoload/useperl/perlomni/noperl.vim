" File: noperl
" Author: lymslive
" Description: perl omni complete with no if_perl support
" Create: 2018-09-07
" Modify: 2018-09-07

let s:omnic = useperl#perlomni#pack()
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
    let cmd = g:perlomni_perl . ' -M' . a:mtext . ' -e "' . escape(a:code,'"') . '"'
    return system(cmd)
endfunction

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
    let l:cache = s:omnic.GetCacheNS('clsf_bcls',a:file)
    if type(l:cache) != type(0)
        return l:cache
    endif
    let list = split(s:system(s:vimbin.'grep-pattern.pl', a:file, s:perlreg.BaseClass),"\n")
    let classes = [ ]
    for i in range(0,len(list)-1)
        let list[i] = substitute(list[i],'^\(qw[(''"\[]\|(\|[''"]\)\s*','','')
        let list[i] = substitute(list[i],'[)''"]$','','')
        let list[i] = substitute(list[i],'[,''"]',' ','g')
        cal extend( classes , split(list[i],'\s\+'))
    endfor
    return s:omnic.SetCacheNS('clsf_bcls',a:file,classes)
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
    let l:cache = s:omnic.GetCacheNS('clsfpath',a:class)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let paths = map(split(&path, '\\\@<![, ]'), 'substitute(v:val, ''\\\([, ]\)'', ''\1'', ''g'')')
    if g:perlomni_use_perlinc || &filetype != 'perl'
        let paths = split(s:system(g:perlomni_perl, '-e', 'print join(",",@INC)') ,',')
    endif

    let filepath = substitute(a:class,'::','/','g') . '.pm'
    cal insert(paths,'lib')
    for path in paths
        if filereadable( path . '/' . filepath )
            return s:omnic.SetCacheNS('clsfpath',a:class,path .'/' . filepath)
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

" SCANNING FUNCTIONS: {{{

" scan exported functions from a module.
function! s:scanModuleExportFunctions(class)
    let l:cache = s:omnic.GetCacheNS('mef',a:class)
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
    return s:omnic.SetCacheNS('mef',a:class, s:toCompHashList(funcs, a:class))
endfunction
" echo s:scanModuleExportFunctions( 'List::MoreUtils' )
" sleep 1

" Scan export functions in current buffer
" Return functions
function! s:scanCurrentExportFunction()
    let l:cache = s:omnic.GetCacheNS('cbexf', bufname('%'))
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
    return s:omnic.SetCacheNS('cbexf',bufname('%'),funcs)
endfunction
" echo s:scanCurrentExportFunction()
" sleep 1

function! s:scanClass(path) " {{{
    let l:cache = s:omnic.GetCacheNS('classpath', a:path)
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
    return s:omnic.SetCacheNS('classpath',a:path,l:files)
endfunction
" echo s:scanClass(expand('~/aiink/aiink/lib'))
" }}}
function! s:scanObjectVariableLines(lines) " {{{
    let varlist = split(s:system(s:vimbin.'grep-objvar.pl', s:tmpfile(a:lines)),"\n")
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
    let list = split(s:system(s:vimbin.'grep-objvar.pl', expand(a:file)),"\n")
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

function! s:scanFunctionFromSingleClassFile(file)
    return split(s:system(s:vimbin.'grep-pattern.pl', a:file, s:perlreg.Function, '|', 'sort', '|', 'uniq'),"\n")
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
        let l:cache = s:omnic.GetCacheNS('classfile_funcs',cls)
        if type(l:cache) != type(0)
            cal extend(l:funcs,l:cache)
            continue
        endif

        let clsfile = s:locateClassFile(cls)
        if clsfile != ''
            let bfuncs = s:scanFunctionFromBaseClassFile( clsfile )
            cal s:omnic.SetCacheNS('classfile_funcs',cls,bfuncs)
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
    let l:cache = s:omnic.GetCacheNS('dbix_c',path)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let pms = split(system('find ' . path . ' -iname "*.pm" | grep Result'),"\n")
    cal map( pms, 'substitute(v:val,''^.*lib/\?'',"","")')
    cal map( pms, 'substitute(v:val,"\\.pm$","","")' )
    cal map( pms, 'substitute(v:val,"/","::","g")' )

    return s:omnic.SetCacheNS('dbix_c',path,pms)
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
    let l:cache = s:omnic.GetCacheNS('variables',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline(1,'$')
    let variables = s:scanVariable(lines)
    cal extend( variables , s:scanArrayVariable(lines))
    cal extend( variables , s:scanHashVariable(lines))
    let result = s:StringFilter(variables, a:base)
    return s:omnic.SetCacheNS('variables',a:base,result)
endfunction

function! s:CompArrayVariable(base,context)
    let l:cache = s:omnic.GetCacheNS('arrayvar',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline(1,'$')
    let variables = s:scanArrayVariable(lines)
    let result = s:StringFilter(variables, a:base)
    return s:omnic.SetCacheNS('arrayvar',a:base,result)
endfunction

function! s:CompHashVariable(base,context)
    let l:cache = s:omnic.GetCacheNS('hashvar',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif
    let lines = getline(1,'$')
    let variables = s:scanHashVariable(lines)
    let result = s:StringFilter(variables, a:base)
    return s:omnic.SetCacheNS('hashvar',a:base,result)
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
    let l:cache = s:omnic.GetCacheNS('buf_func',a:base.expand('%'))
    if type(l:cache) != type(0)
        return l:cache
    endif

    let l:cache2 = s:omnic.GetCacheNS('buf_func_all',expand('%'))
    if type(l:cache2) != type(0)
        let funclist = l:cache2
    else
        let lines = getline(1,'$')
        let funclist = s:omnic.SetCacheNS('buf_func_all',expand('%'),s:scanFunctionFromList(lines))
    endif
    let result = s:StringFilter(funclist, a:base)
    return s:omnic.SetCacheNS('buf_func',a:base.expand('%'),result)
endfunction

function! s:CompClassFunction(base,context)
    let class = matchstr(a:context,'[a-zA-Z0-9:]\+\(->\)\@=')
    let l:cache = s:omnic.GetCacheNS('classfunc',class.'_'.a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let l:cache2 = s:omnic.GetCacheNS('class_func_all',class)
    let funclist = type(l:cache2) != type(0) ? l:cache2 : s:omnic.SetCacheNS('class_func_all',class,s:scanFunctionFromClass(class))

    let result = s:StringFilter(funclist, a:base)
    let funclist = s:omnic.SetCacheNS('classfunc',class.'_'.a:base,result)
    if g:perlomni_show_hidden_func == 0
        call filter(funclist, 'v:val !~ "^_"')
    endif
    return funclist
endfunction

function! s:CompObjectMethod(base,context)
    let objvarname = matchstr(a:context,'\$\w\+\(->$\)\@=')
    let l:cache = s:omnic.GetCacheNS('objectMethod',objvarname.'_'.a:base)
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
        let funclist = s:omnic.SetCacheNS('objectMethod',objvarname.'_'.a:base,result)
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
    let cache = s:omnic.GetCacheNS('class',a:base)
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
    return s:omnic.SetCacheNS('class',a:base,result)
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

cal s:rule({ 'name' : 'BufferMethod',
            \'context': '\$\(self\|class\)->$',
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

" End Load: {{{1
function! useperl#perlomni#noperl#load() abort "{{{
    return 0
endfunction "}}}

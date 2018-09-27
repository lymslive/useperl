" File: scanps
" Author: lymslive
" Description: dynamic scan omni complete data with system perl script
" Create: 2018-09-07
" Modify: 2018-09-09

" Import:
let s:dynamic = useperl#perlomni#cache#pack()

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

" Scan Utils: {{{1
function! s:system(...) "{{{
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
endfunction "}}}

function! s:runPerlEval(mtext,code)
    let cmd = g:perlomni_perl . ' -M' . a:mtext . ' -e "' . escape(a:code,'"') . '"'
    return system(cmd)
endfunction

" GetPerlInc: 
let s:INC = []
function! s:GetPerlInc() abort "{{{
    if empty(s:INC)
        let s:INC = split(s:system(g:perlomni_perl, '-e', 'print join(",",@INC)') ,',')
    endif
    return s:INC
endfunction "}}}

" return buffer list (of number) that file name match pattern
function! s:grepBufferList(pattern) "{{{
    redir => bufferlist
    silent buffers
    redir END
    let lines = split(bufferlist,"\n")
    let files = []
    let buffers = []
    for line in lines
        let buffile = matchstr(line, '\("\)\@<=\S\+\("\)\@=' )
        if buffile =~ a:pattern
            call add(files,expand(buffile))
            let buf = matchstr(line, '^\s*\zs\d\+\ze')
            call add(buffers, buf)
        endif
    endfor
    " return files
    return buffers
endfunction "}}}
" echo s:grepBufferList('\.pm$')

" tmpfile: save some line in tmpfile, and return the file name 
function! s:tmpfile(lines) abort "{{{
    let l:buffile = tempname()
    cal writefile(a:lines, l:buffile)
    return l:buffile
endfunction "}}}

let s:REGP = {}
let s:REGP.BaseClass = '^(?:use\s+(?:base|parent)\s+|extends\s+)(.*);'
let s:REGP.Function = '^\s*(?:sub|has)\s+(\w+)'
let s:REGP.QString = '[''](.*?)(?<!\\)['']'
let s:REGP.QQString = '["](.*?)(?<!\\)["]'

let s:REGV = {}
let s:REGV.Module = '[a-zA-Z][a-zA-Z0-9:]\+'

" Main Scanning Part: {{{1

" SCAN VARIABLES:  "{{{2
function! s:scanVariable(buf)
    let l:cache = s:dynamic.GetCache('Variables', a:buf)
    if !empty(l:cache)
        return l:cache
    endif
    let l:lines = getbufline(a:buf, 1, '$')
    let result = split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(l:lines), '\$(\w+)', '|', 'sort', '|', 'uniq'),"\n")
    return s:dynamic.SetCache(result, 'Variables', a:buf)
endfunction

function! s:scanArrayVariable(buf)
    let l:cache = s:dynamic.GetCache('VarArray', a:buf)
    if !empty(l:cache)
        return l:cache
    endif
    let l:lines = getbufline(a:buf, 1, '$')
    let result = split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(l:lines), '@(\w+)', '|', 'sort', '|', 'uniq'),"\n")
    return s:dynamic.SetCache(result, 'VarArray', a:buf)
endfunction

function! s:scanHashVariable(buf)
    let l:cache = s:dynamic.GetCache('VarHash',a:buf)
    if !empty(l:cache)
        return l:cache
    endif
    let l:lines = getbufline(a:buf, 1, '$')
    let result = split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(l:lines), '%(\w+)', '|', 'sort', '|', 'uniq'),"\n")
    return s:dynamic.SetCache(result, 'VarHash', a:buf)
endfunction

" Cache ClassLocal:
function! s:scanClass(path) " {{{
    let l:cache = s:dynamic.GetCache('ClassLocal', a:path)
    if !empty(l:cache)
        return l:cache
    endif
    if ! isdirectory(a:path)
        return [ ]
    endif
    let l:files = split(glob(a:path . '/**'))
    cal filter(l:files, 'v:val =~ "\.pm$"')
    cal map(l:files, 'strpart(v:val,strlen(a:path)+1,strlen(v:val)-strlen(a:path)-4)')
    cal map(l:files, 'substitute(v:val,''/'',"::","g")')
    return s:dynamic.SetCache(l:files, 'ClassLocal', a:path)
endfunction
" echo s:scanClass(expand('~/aiink/aiink/lib'))
" }}}

" SCAN FUNCTIONS:  "{{{2

" Cache CurrentImport:
" cache = [used module name list]
function! s:scanModuleImported(buf) abort "{{{
    let l:cache = s:dynamic.GetCache('CurrentImport', a:buf)

    if !empty(l:cache)
        return l:cache
    endif

    let l:imorted = []
    let lines = getbufline(bufnr(a:buf), 1, "$")
    cal filter(lines, 'v:val =~ ''^\s*\(use\|require\)\s''')
    for line in lines
        let m = matchstr(line, '\(^use\s\+\)\@<=' . s:REGV.Module)
        if strlen(m) > 0
            call add(l:imorted, m)
        endif
    endfor

    return s:dynamic.SetCache(l:imorted, 'CurrentImport', a:buf)
endfunction "}}}

" Cache ModuleExport:
" scan exported functions from a module.
function! s:scanModuleExportFunctions(class) "{{{
    if !g:perlomni_export_functions
        return []
    endif
    let l:cache = s:dynamic.GetCache('ModuleExport',a:class)
    if !empty(l:cache)
        return l:cache
    endif

    let funcs = []
    let output = s:runPerlEval( a:class , printf( 'print join " ",@%s::EXPORT_OK' , a:class ))
    cal extend( funcs , split( output ) )
    let output = s:runPerlEval( a:class , printf( 'print join " ",@%s::EXPORT' , a:class ))
    cal extend( funcs , split( output ) )
    let l:export = uniq(sort(funcs))
    if empty(l:export)
        return []
    endif

    return s:dynamic.SetCache(l:export, 'ModuleExport', a:class)
    " let l:cache = {'word': l:export, 'menu': a:class}
    " return s:dynamic.SetCache(l:cache, 'ModuleExport', a:class)
endfunction "}}}
" echo s:scanModuleExportFunctions( 'List::MoreUtils' )

" Func: s:scanModuleSymbol 
function! s:scanModuleSymbol(module, base) abort "{{{
    let l:lsSymbol = s:scanModuleExportFunctions(a:module)
    if !empty(a:base)
        call filter(l:lsSymbol, 'v:val =~# "^" . a:base')
    endif
    return l:lsSymbol
endfunction "}}}

" Cache BufferFunction:
" scanBufferFunction: 
function! s:scanBufferFunction(buf) abort "{{{
    let l:cache = s:dynamic.GetCache('BufferFunction', a:buf)
    if !empty(l:cache)
        return l:cache
    endif
    let l:lines = getbufline(a:buf, 1,'$')
    let funclist = split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(l:lines), s:REGP.Function, '|', 'sort', '|', 'uniq'),"\n")
    return s:dynamic.SetCache(funclist, 'BufferFunction', a:buf)
endfunction "}}}

" SCAN CLASS BASE AND METHOD: {{{2

" Cache ClassFile: full path of a class module
function! s:locateClassFile(class) "{{{
    let l:cache = s:dynamic.GetCache('ClassFile',a:class)
    if !empty(l:cache)
        return l:cache
    endif

    let l:inc = s:GetPerlInc()
    if !empty(g:perlomni_local_lib)
        let l:cwd = expand('%:p:h')
        let l:local = map(copy(g:perlomni_local_lib), 'l:cwd . "/" . v:val')
        let l:inc = extend(l:local, l:inc)
    endif

    let filepath = substitute(a:class,'::','/','g') . '.pm'
    for path in l:inc
        let l:full = path . '/' . filepath
        if filereadable(l:full)
            return s:dynamic.SetCache(l:full, 'ClassFile', a:class)
        endif
    endfor
    return ''
endfunction "}}}
" echo s:locateClassFile('Jifty::DBI')
" echo s:locateClassFile('No')

function! s:baseClassFromFile(file) "{{{
    let list = split(s:system(s:vimbin.'grep-pattern.pl', a:file, s:REGP.BaseClass),"\n")
    let l:classes = [ ]
    for i in range(0,len(list)-1)
        let list[i] = substitute(list[i],'^\(qw[(''"\[]\|(\|[''"]\)\s*','','')
        let list[i] = substitute(list[i],'[)''"]$','','')
        let list[i] = substitute(list[i],'[,''"]',' ','g')
        cal extend(l:classes, split(list[i],'\s\+'))
    endfor
    return l:classes
endfunction "}}}
" echo s:baseClassFromFile(expand('%'))

" Cache ClassBased: directory base class of file
function! s:scanBaseClass(class) "{{{
    let l:cache = s:dynamic.GetCache('ClassBased',a:class)
    if !empty(l:cache)
        return l:cache
    endif

    let file = s:locateClassFile(a:class)
    if file == ''
        return []
    endif
    let l:classes = s:baseClassFromFile(file)
    return s:dynamic.SetCache(classes, 'ClassBased', a:class)
endfunction "}}}
" echo s:scanBaseClass( 'Jifty::Record' )

" Cache CurrentBased:
function! s:scanCurrentBaseClass() "{{{
    let l:cache = s:dynamic.GetCache('CurrentBased', bufnr('%'))
    if !empty(l:cache)
        return l:cache
    endif

    let all_mods = [ ]
    for i in range( line('.') , 1 , -1 )
        let line = getline(i)
        if line =~ '^package\s\+'
            break
        elseif line =~ '^\(use\s\+\(base\|parent\)\|extends\)\s\+'
            let args =  matchstr( line ,
                        \ '\(^\(use\s\+\(base\|parent\)\|extends\)\s\+\(qw\)\=[''"(\[]\)\@<=\_.*\([\)\]''"]\s*;\)\@=' )
            let args = substitute(args, '\_[ ]\+' , ' ' , 'g' )
            let mods = split(args, '\s' )
            cal extend(all_mods , mods )
        endif
    endfor

    return s:dynamic.SetCache(all_mods, 'CurrentBased', bufnr('%'))
endfunction "}}}

" Cache ClassFunction: cache functions for each class include based
function! s:scanClassFunction(class)
    let l:cache = s:dynamic.GetCache('ClassFunction', a:class)
    if !empty(l:cache)
        return l:cache
    endif
    let l:funcs = s:scanClassFunctionFromBase(a:class)
    call uniq(sort(l:funcs))
    return s:dynamic.SetCache(l:funcs, 'ClassFunction', a:class)
endfunction
" echo s:scanClassFunction('Jifty::DBI::Record')
" echo s:scanClassFunction('CGI')

function! s:scanClassFunctionFromSingle(class)
    let l:cache = s:dynamic.GetCache('ClassFuncSingle', a:class)
    if !empty(l:cache)
        return l:cache
    endif
    let l:file = s:locateClassFile(a:class)
    if !filereadable( l:file )
        return []
    endif

    let l:funcs = split(s:system(s:vimbin.'grep-pattern.pl', l:file, s:REGP.Function),"\n")
    return s:dynamic.SetCache(l:funcs, 'ClassFuncSingle', a:class)
endfunction

" recursively scan functions from parent classes.
function! s:scanClassFunctionFromBase(class) "{{{
    let l:result = []
    let l:funcs = s:scanClassFunctionFromSingle(a:class)
    call extend(l:result, l:funcs)
    let classes = s:scanBaseClass(a:class)
    for cls in classes
        let l:bfuncs = s:scanClassFunctionFromBase( cls )
        cal extend(l:result, l:bfuncs)
    endfor
    return l:result
endfunction "}}}
" let fs = s:scanClassFunctionFromBase(expand('%'))
" }}}

" Sacn ObjectClass: b:objvarMapping
" scan object belong to which class(es)
function! s:scanObjectClass(objvarname) abort "{{{
    if exists('b:objvarMapping') && has_key(b:objvarMapping, a:objvarname)
        return b:objvarMapping[a:objvarname]
    endif

    call s:scanObjectVariable(bufnr('%'))
    if exists('b:objvarMapping') && has_key(b:objvarMapping, a:objvarname)
        return [a:objvarname]
    endif

    if !has_key(b:objvarMapping, objvarname)
        let l:buffers = s:grepBufferList('\.p[ml]$')
        for l:buf in bufferfiles
            if l:buf != bufnr('%')
                call s:scanObjectVariable(l:buf)
            endif
        endfor
    endif

    return get(b:objvarMapping, a:objvarname, [])
endfunction "}}}

function! s:scanObjectVariable(buf) "{{{
    let l:lines = getbufline(a:buf, 1,'$')
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
endfunction "}}}
" echo s:scanObjectVariableLines([])

function! s:scanQString(lines)
    return split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(a:lines), s:REGP.QString) ,"\n")
endfunction
function! s:scanQQString(lines)
    return split(s:system(s:vimbin.'grep-pattern.pl', s:tmpfile(a:lines), s:REGP.QQString),"\n")
endfunction
" }}}

" End Export: {{{1
let s:_export = {}
let s:_export.scanArrayVariable = function('s:scanArrayVariable')
let s:_export.scanBufferFunction = function('s:scanBufferFunction')
let s:_export.scanClass = function('s:scanClass')
let s:_export.scanClassFunction = function('s:scanClassFunction')
let s:_export.scanCurrentBaseClass = function('s:scanCurrentBaseClass')
let s:_export.scanHashVariable = function('s:scanHashVariable')
let s:_export.scanModuleExportFunctions = function('s:scanModuleExportFunctions')
let s:_export.scanModuleSymbol = function('s:scanModuleSymbol')
let s:_export.scanModuleImported = function('s:scanModuleImported')
let s:_export.scanObjectClass = function('s:scanObjectClass')
let s:_export.scanQString = function('s:scanQString')
let s:_export.scanVariable = function('s:scanVariable')
function! useperl#perlomni#scanps#export() abort "{{{
    return s:_export
endfunction "}}}

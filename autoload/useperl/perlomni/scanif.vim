" File: scanif
" Author: lymslive
" Description: dynamic scan omin complete data with if_perl support
" Create: 2018-09-07
" Modify: 2018-09-09

" Import:
let s:ifperl = useperl#ifperl#pack()
let s:dynamic = useperl#perlomni#cache#pack()
:PerlUse Perlomni

" Scan Utils: {{{1
" GetPerlInc: 
let s:INC = []
function! s:GetPerlInc() abort "{{{
    if empty(s:INC)
        let s:INC = split(s:ifperl.call('GotIncPath'), ',')
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
    let result = split(s:ifperl.call('Perlomni::ScanBufUniq', a:buf, '\$(\w+)'),"\n")
    return s:dynamic.SetCache(result, 'Variables', a:buf)
endfunction

function! s:scanArrayVariable(buf)
    let l:cache = s:dynamic.GetCache('VarArray', a:buf)
    if !empty(l:cache)
        return l:cache
    endif
    let result = split(s:ifperl.call('Perlomni::ScanBufUniq', a:buf, '@(\w+)'),"\n")
    return s:dynamic.SetCache(result, 'VarArray', a:base)
endfunction

function! s:scanHashVariable(buf)
    let l:cache = s:dynamic.GetCache('VarHash',a:buf)
    if !empty(l:cache)
        return l:cache
    endif
    let l:lines = getbufline(a:buf, 1, '$')
    let result = split(s:ifperl.call('Perlomni::ScanBufUniq', a:buf, '%(\w+)'),"\n")
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

    let l:code = printf('require %s; print join " ", (@%s::EXPORT_OK, @%s::EXPORT);', a:class, a:class, a:class)
    let l:output = s:ifperl.execute(l:code)
    let l:export = uniq(sort(split(l:output)))
    if empty(l:export)
        return []
    endif

    return s:dynamic.SetCache(l:export, 'ModuleExport', a:class)
endfunction "}}}
" echo s:scanModuleExportFunctions( 'List::MoreUtils' )

" Cache BufferFunction:
" scanBufferFunction: 
function! s:scanBufferFunction(buf) abort "{{{
    let l:cache = s:dynamic.GetCache('BufferFunction', a:buf)
    if !empty(l:cache)
        return l:cache
    endif
    let funclist = split(s:ifperl.call('Perlomni::ScanBufUniq', a:buf, s:REGP.Function),"\n")
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
    let list = split(s:ifperl.call('Perlomni::GrepPattern', a:file, s:REGP.BaseClass), "\n")
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
    return s:omnic.SetCache(classes, 'ClassBased', a:class)
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

    let l:funcs = split(s:ifperl.call('Perlomni::GrepPattern', l:file, s:REGP.Function), "\n")
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
        return = b:objvarMapping[a:objvarname]
    endif

    call s:scanObjectVariable(bufnr('%'))
    if exists('b:objvarMapping') && has_key(b:objvarMapping, a:objvarname)
        return = b:objvarMapping[a:objvarname]
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
    let varlist = split(s:ifperl.call('Perlomni::ScanBufObjval', a:buf),"\n")
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

function! s:scanQString(buf)
    return split(s:ifperl.call('Perlomni::ScanBufUniq', a:buf, s:REGP.QString),"\n")
endfunction
function! s:scanQQString(buf)
    return split(s:ifperl.call('Perlomni::ScanBufUniq', a:buf, s:REGP.QQString),"\n")
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
let s:_export.scanModuleImported = function('s:scanModuleImported')
let s:_export.scanObjectClass = function('s:scanObjectClass')
let s:_export.scanQString = function('s:scanQString')
let s:_export.scanVariable = function('s:scanVariable')
function! useperl#perlomni#scanif#export() abort "{{{
    return s:_export
endfunction "}}}

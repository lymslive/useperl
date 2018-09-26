" File: rule
" Author: lymslive
" Description: perl omni complete rule implementation
" Create: 2018-09-07
" Modify: 2018-09-09

" Import:
let s:omnic = useperl#perlomni#pack()
let s:rule = s:omnic.AddRule
let s:static = useperl#perlomni#data#pack()

if g:perlomni_enable_ifperl
    " :USE useperl#perlomni#scanif
    let s:SN = useperl#perlomni#scanif#export()
else
    " :USE useperl#perlomni#scanps
    let s:SN = useperl#perlomni#scanps#export()
endif

" COMPLETION PARSE UTILS: {{{1

" Trival Util Functions: {{{

function! s:Quote(list)
    return map(copy(a:list), '"''".v:val."''"' )
endfunction

function! s:ShellQuote(s)
    return &shellxquote == '"' ? "'".a:s."'" : '"'.a:s.'"'
endfunction

function! s:RegExpFilter(list,pattern)
    return filter(copy(a:list),"v:val =~ a:pattern")
endfunction

function! s:StringFilter(list,string)
    return filter(copy(a:list),"stridx(v:val,a:string) == 0 && v:val != a:string" )
endfunction
" }}}

" toCompHashList: 
" a group list of word may share the same menu
" input: {word => [...], menu => m}
" output: [{word => w1, menu =>m}, {word => w1, menu =>m}, ..]
" a:1, also filter with prefix as s:StringFilter()
function! s:toCompHashList(dict, ...) abort "{{{
    let l:words = get(a:dict, 'word', [])
    if empty(l:words)
        return []
    endif

    let l:words = copy(l:words)
    if a:0 > 0 && !empty(a:1)
        let l:prefix = a:1
        call filter(l:words,"stridx(v:val, l:prefix) == 0 && v:val != l:prefix" )
    endif

    let l:menu = get(a:dict, 'menu', '')
    return map(l:words, '{ "word": v:val , "menu": "'. l:menu .'" }' )
endfunction "}}}

" PickFilter: filter large list
" pick matched item one by one, avoid copy large list
" a:1, optional max items to be picked
function! s:PickFilter(list, string, ...) abort "{{{
    let l:result = []
    let l:max = get(a:000, 0, 0)
    let l:pattern = '^' . a:string
    for l:item in a:list
        if l:item =~# l:pattern && (l:max <=0 || len(l:result) < l:max)
            call add(l:result, l:item)
        endif
    endfor
    return l:result
endfunction "}}}

let s:REGV = {}
let s:REGV.Module = '[a-zA-Z][a-zA-Z0-9:]\+'

" PERL CORE OMNI COMPLETION: {{{1

" Key Words: {{{
function! s:CompUnderscoreTokens(base,context)
    let l:list = s:static.GetData('core.Underscore')
    let l:comp = {'word': l:list, 'menu': 'CORE'}
    return s:toCompHashList(l:comp, a:base)
endfunction

cal s:rule({ 'name' : 'UnderscoreTokens',
            \'only':1,
            \'context': '$',
            \'backward': '__[A-Z]*$',
            \'comp': function('s:CompUnderscoreTokens') })
"}}}
" POD: {{{
function! s:CompPodHeaders(base,context)
    let l:list = s:static.GetData('core.PodHead')
    let l:comp = {'word': l:list, 'menu': 'POD'}
    return s:toCompHashList(l:comp, a:base)
endfunction
cal s:rule({ 'name' : 'Pod::Headers',
            \'only':1, 
            \'context': '^=$',
            \'backward': '\w*$',
            \'comp': function('s:CompPodHeaders') })

function! s:CompPodSections(base,context)
    let l:list = s:static.GetData('core.PodSection')
    let l:comp = {'word': l:list, 'menu': 'POD'}
    return s:toCompHashList(l:comp, a:base)
endfunction
cal s:rule({ 'name' : 'Pod::Sections',
            \'only':1,
            \'context': '^=\w\+\s',
            \'backward': '\w*$',
            \'comp': function('s:CompPodSections') })
"}}}
" Variable:{{{

function! s:CompVariable(base,context)
    let l:list = s:SN.scanVariable(bufnr('%'))
    let l:comp = {'word': l:list, 'menu': '$scalar'}
    let l:scalar = s:toCompHashList(l:comp, a:base)

    let l:list = s:SN.scanArrayVariable(bufnr('%'))
    let l:comp = {'word': l:list, 'menu': '@array'}
    let l:array = s:toCompHashList(l:comp, a:base)

    let l:list = s:SN.scanHashVariable(bufnr('%'))
    let l:comp = {'word': l:list, 'menu': '%hash'}
    let l:hash = s:toCompHashList(l:comp, a:base)

    return l:scalar + l:array + l:hash
endfunction
cal s:rule({ 'name' : 'Variable',
            \'only':1,
            \'context': '\${\?$',
            \'backward': '\w*$',
            \'comp': function('s:CompVariable') })

function! s:CompArrayVariable(base,context)
    let l:list = s:SN.scanArrayVariable(bufnr('%'))
    let l:comp = {'word': l:list, 'menu': '@array'}
    let l:array = s:toCompHashList(l:comp, a:base)
    return l:array
endfunction
cal s:rule({ 'name' : 'ArrayVariable',
            \'only':1,
            \'context': '@{\?$',
            \'backward': '\w*$',
            \'comp': function('s:CompArrayVariable') })

function! s:CompHashVariable(base,context)
    let l:list = s:SN.scanHashVariable(bufnr('%'))
    let l:comp = {'word': l:list, 'menu': '%hash'}
    let l:hash = s:toCompHashList(l:comp, a:base)
    return l:hash
endfunction
cal s:rule({ 'name' : 'HashVariable',
            \'only':1,
            \'context': '%{\?$',
            \'backward': '\w*$',
            \'comp': function('s:CompHashVariable') })
"}}}
" Class: {{{
function! s:CompClassName(base,context)
    if strlen(a:base) == 0
        return [ ]
    endif

    let l:hostm = s:static.GetData('host.Module')
    let l:result = s:PickFilter(l:hostm, a:base, g:perlomni_max_class_length)

    for l:lib in g:perlomni_local_lib
        let l:path = expand('%:p:h') . '/' . l:lib
        let l:local = s:SN.scanClass(l:path)
        let l:local = s:StringFilter(l:local, a:base)
        call extend(l:result, l:local)
    endfor

    if g:perlomni_sort_class_by_lenth
        cal sort(l:result,'s:SortByLength')
    else
        cal sort(l:result)
    endif

    let l:comp = {'word': l:result, 'menu': 'Class'}
    return s:toCompHashList(l:comp)
endfunction

function! s:SortByLength(i, j)
    return strlen(a:i) == strlen(a:j) ? 0 : strlen(a:i) > strlen(a:j) ? 1 : -1
endfunction

" echo s:CompClassName('Moose::','')

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

" donot want context match any thing
" todo: ClassSymbol not only ClassName
cal s:rule({ 'name' : 'ClassSymbol',
            \'context': '$' ,
            \'backward': '\<\u\w*::[a-zA-Z0-9:]*$',
            \'comp': function('s:CompClassName') } )
"}}}
" Function:{{{
function! s:CompFunction(base,context)
    let l:builtin = s:static.GetData('core.Function')
    let l:builtin = {'word': l:builtin, 'menu': 'core'}
    let l:result = s:toCompHashList(l:builtin, a:base)

    for l:import in s:SN.scanModuleImported(bufnr('%'))
        let l:export = s:SN.scanModuleExportFunctions(l:import)
        let l:export = {'word': l:export, 'menu': l:import}
        cal extend(l:result, s:toCompHashList(l:export, a:base))
    endfor
    return l:result
endfunction
cal s:rule({ 'name' : 'Function',
            \'context': '\(->\|\$\)\@<!$',
            \'backward': '\<\w\+$' ,
            \'comp': function('s:CompFunction') })

function! s:CompExportFunction(base,context)
    let mod = matchstr( a:context , '\(^use\s\+\)\@<=' . s:REGV.Module )
    let l:export = s:SN.scanModuleExportFunctions(mod)
    let l:export = {'word': l:export, 'menu': mod}
    let l:words = s:toCompHashList(l:export, a:base)
    return l:words
endfunction
cal s:rule({ 'name' : 'ExportFunction',
            \'only': 1,
            \'context': '^use\s\+[a-zA-Z0-9:]\+\s\+qw',
            \'backward': '\w*$',
            \'comp': function('s:CompExportFunction') })

function! s:CompBufferFunction(base,context)
    let l:result = s:SN.scanBufferFunction(bufnr('%'))
    let l:comp = {'word': l:result, 'menu': 'BufSub'}
    return s:toCompHashList(l:comp, a:base)
endfunction
cal s:rule({ 'name' : 'BufferFunction',
            \'only':1,
            \'context': '&$',
            \'backward': '\w*$',
            \'comp': function('s:CompBufferFunction') })
cal s:rule({ 'name' : 'BufferMethod',
            \'context': '\$\(self\|class\)->$',
            \'backward': '\w*$' ,
            \'only':1 ,
            \'comp': function('s:CompBufferFunction') })

function! s:CompClassFunction(base,context)
    let class = matchstr(a:context,'[a-zA-Z0-9:]\+\(->\)\@=')
    let l:list = s:SN.scanClassFunction(class)
    let l:comp = {'word': l:list, 'menu': l:class}
    return s:toCompHashList(l:comp, a:base)
endfunction
cal s:rule({ 'name' : 'ClassFunction',
            \'context': '\<[a-zA-Z0-9:]\+->$',
            \'backward': '\w*$',
            \'comp': function('s:CompClassFunction') })

function! s:CompCurrentBaseFunction(base,context)
    let l:base = s:SN.scanCurrentBaseClass()
    let l:result = [ ]
    for l:class in l:base
        let l:list = s:SN.scanClassFunction(l:class)
        let l:comp = {'word': l:list, 'menu': l:class}
        let l:sublist = s:toCompHashList(l:comp, a:base)
        call extend(l:result, l:sublist)
    endfor
    return l:result
endfunction
cal s:rule({ 'name' : 'BaseFunction',
            \'context': '^\s*\(sub\|method\)\s\+',
            \'backward': '\<\w\+$' ,
            \'only':1 ,
            \'comp': function('s:CompCurrentBaseFunction') })

function! s:CompObjectMethod(base,context)
    let l:objvarname = matchstr(a:context,'\$\w\+\(->$\)\@=')
    let l:classes = s:SN.scanObjectClass(l:objvarname)
    let l:result = []
    for l:cls in l:classes
        let l:list = s:SN.scanClassFunction(l:cls)
        let l:comp = {'word': l:list, 'menu': l:cls}
        let l:sublist = s:toCompHashList(l:comp, a:base)
        cal extend(l:result, l:sublist)
    endfor
    return l:result
endfunction
cal s:rule({ 'name' : 'ObjectMethod',
            \'context': '\$\w\+->$',
            \'backward': '\<\w\+$',
            \'comp': function('s:CompObjectMethod') })
"}}}
" String: {{{
" string completion
function! s:CompQString(base, context)
    let l:strings = s:SN.scanQString(bufnr('%'))
    let l:comp = {'word': l:strings, 'menu': 'BufSub'}
    return s:toCompHashList(l:comp, a:base)
endfunction
" cal s:rule({'context': '\s''', 'backward': '\_[^'']*$' , 'comp': function('s:CompQString') })
"}}}

" SIMPLE MOOSE COMPLETION: {{{1
function! s:CompMooseIs(base,context)
    " return s:Quote(['rw', 'ro', 'wo'])
    let l:is = s:static.GetData('moose.Is')
    let l:is = s:Quote(l:is)
    return s:toCompHashList({'word': l:is, 'menu': 'Moose'})
endfunction
cal s:rule({ 'name' : 'Moose::Is',
            \'only':1,
            \'head': '^has\s\+\w\+' ,
            \'context': '\s\+is\s*=>\s*$',
            \'backward': '[''"]\?\w*$' ,
            \'comp': function('s:CompMooseIs') } )

function! s:CompMooseIsa(base,context)
    let l:base = substitute(a:base,'^[''"]','','')
    let l:types = s:static.GetData('moose.Isa')
    let l:types = s:Quote(s:StringFilter(l:types, l:base))
    let l:comps = s:toCompHashList({'word': l:types, 'menu': 'Moose'})
    cal extend(l:comps, s:CompClassName(l:base,a:context))
    return l:comps
endfunction
cal s:rule({ 'name' : 'Moose::Isa',
            \'only':1,
            \'head': '^has\s\+\w\+' ,
            \'context': '\s\+\(isa\|does\)\s*=>\s*$' ,
            \'backward': '[''"]\?\S*$' ,
            \'comp': function('s:CompMooseIsa') } )

function! s:CompMooseAttribute(base,context)
    let l:values = s:static.GetData('moose.Attribute')
    let l:values = s:StringFilter(l:values, a:base)
    cal map(l:values,'v:val . " => "')
    return s:toCompHashList({'word': l:values, 'menu': 'Moose'})
endfunction
cal s:rule({ 'name' : 'Moose::Attribute',
            \'only':1,
            \'head': '^has\s\+\w\+',
            \'context': '^\s*$',
            \'backward': '\w*$',
            \'comp': function('s:CompMooseAttribute') } )

function! s:CompMooseRoleAttr(base,context)
    " let attrs = [ 'alias', 'excludes' ]
    let l:roles = s:static.GetData('moose.RoleAttr')
    return s:toCompHashList({'word': l:roles, 'menu': 'Moose'}, a:base)
endfunction
cal s:rule({ 'name' : 'Moose::RoleAttr',
            \'only':1,
            \'head': '^with\s\+',
            \'context': '^\s*-$',
            \'backward': '\w\+$',
            \'comp': function('s:CompMooseRoleAttr') } )

function! s:CompMooseStatement(base,context)
    let l:states = s:static.GetData('moose.Statement')
    return s:toCompHashList({'word': l:states, 'menu': 'moose'}, a:base)
endfunction
cal s:rule({ 'name' : 'Moose::Statement',
            \'context': '^\s*$',
            \'backward': '\w\+$',
            \'comp':function('s:CompMooseStatement')})


" reuse s:CompBufferFunction
cal s:rule({ 'name' : 'Moose::BufferFunction',
            \'only':1, 
            \'head': '^has\s\+\w\+',
            \'context': '\s\+\(reader\|writer\|clearer\|predicate\|builder\)\s*=>\s*[''"]$' ,
            \'backward': '\w*$',
            \'comp': function('s:CompBufferFunction') })


" DBI METHOD COMPLETION: {{{1
function! s:CompDBIxMethod(base,context)
    let l:methods = s:static.GetData('dbix.Method')
    return s:toCompHashList('word': l:methods, 'menu': 'DBIx', a:base)
endfunction
cal s:rule({ 'name' : 'DBIx::Method',
            \'context': '^__PACKAGE__->$',
            \'contains': 'DBIx::Class::Core',
            \'backward': '\w*$',
            \'comp':    function('s:CompDBIxMethod')
            \})

function! s:CompDBIxResultClassName(base,context)
    let l:path = 'lib'
    let l:path = expand('%:p:h') . '/' . l:path
    let l:result = s:SN.scanClass(l:path)
    call filter(copy(l:result), 'v:val =~? "Result)
    let l:comp = {'word': l:result, 'menu': 'DBIx-Result'}
    return s:toCompHashList(l:comp, a:base)
endfunction
cal s:rule({ 'name' : 'DBIx::ResultClass',
            \'only': 1,
            \'context': '->resultset(\s*[''"]',
            \'backward': '\w*$',
            \'comp':  function('s:CompDBIxResultClassName') } )


" MODULE INSTALL COMPLETION: {{{1
function! s:CompModuleInstallExport(base,context)
    let l:list = s:static.GetData('inst.Metadata')
    let l:comp = {'word': l:list, 'menu': 'Module::Install::Metadata'}
    return s:toCompHashList(l:comp, a:base)
endfunction
cal s:rule({ 'name' : 'ModuleInstallExport',
            \'contains'  :  'Module::Install',
            \'backward'  :  '\w*$',
            \'context'   :  '^$',
            \'comp'      :  function('s:CompModuleInstallExport') })

function! s:CompClassNameCPAN(base,context)
    if strlen(a:base) == 0
        return [ ]
    endif
    let l:cpanm = s:static.GetData('cpan.Module')
    let result = s:PickFilter(l:cpanm, a:base, g:perlomni_max_class_length)
    if g:perlomni_sort_class_by_lenth
        cal sort(result,'s:SortByLength')
    else
        cal sort(result)
    endif
    let l:comp = {'word': result, 'menu': 'CPAN'}
    return s:toCompHashList(l:comp, a:base)
endfunction
cal s:rule({ 'name' : 'ModuleInstall',
            \'context': '^\(requires\|build_requires\|test_requires\)\s',
            \'backward': '[a-zA-Z0-9:]*$',
            \'comp': function('s:CompClassNameCPAN') })


" End Load: {{{1
function! useperl#perlomni#rule#load() abort "{{{
    return 0
endfunction "}}}

" File: perldoc
" Author: lymslive
" Description: use perldoc within vim to read perl document
"   based on: https://github.com/hotchpotch/perldoc-vim
" Create: 2018-09-27
" Modify: 2018-09-27

if exists("g:loaded_perldoc")
  finish
endif
let g:loaded_perldoc = 1

let s:buf_nr = -1
let s:mode = ''
let s:last_word = ''
let s:last_class = 0
let s:buffer = ''

function! s:PerldocView()
    let split_modifier = get(g:, 'perldoc_split_modifier', '')
    if !bufexists(s:buf_nr)
        let cwd = getcwd()
        exe 'leftabove ' . split_modifier . 'new'
        file `="[Perldoc]"`
        let s:buf_nr = bufnr('%')
        call s:Setlocal()
        execute ':lcd ' . cwd
    elseif bufwinnr(s:buf_nr) == -1
        exe 'leftabove ' . split_modifier . 'split'
        execute s:buf_nr . 'buffer'
        " delete _
    elseif bufwinnr(s:buf_nr) != bufwinnr('%')
        execute bufwinnr(s:buf_nr) . 'wincmd w'
    endif
endfunction

function! s:Setlocal()
    setlocal filetype=man
    setlocal bufhidden=hide
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nobuflisted
    setlocal modifiable
    setlocal nocursorline
    setlocal nocursorcolumn
    setlocal iskeyword+=:
    setlocal iskeyword-=-

    noremap <buffer> <silent> K :Perldoc<CR>
    noremap <buffer> <silent> <CR> :Perldoc <C-R><C-W>
    noremap <buffer> <silent> s :call <SID>Toggle()<CR>
endfunction

function! s:PerldocWord(word)
    if a:word ==# s:last_word || s:ClassExist(a:word) || s:FuncExist(a:word) || s:VarsExist(a:word)
        call s:ShowDoc()
        let s:mode = ''
        setfiletype man
        let s:last_word = a:word
    else
        echo 'No documentation found for "' . a:word . '".'
        return -1
    endif
endfunction

function! s:PerldocSource()
    if s:last_class
        call s:ShowDoc('0read!perldoc -m ' . s:last_word)
        let s:mode = 'source'
        setfiletype perl
    end
endfunction

function! s:Toggle()
    if s:mode ==? 'source'
        call s:PerldocWord(s:last_word)
    else
        call s:PerldocSource()
    end
endfunction

function! s:ShowDoc(...)
    silent call s:PerldocView()
    setlocal modifiable
    1,$ delete _
    if a:0 > 0 && !empty(a:1)
        execute a:1
    elseif !empty(s:buffer)
        call append(0, s:buffer)
    endif
    setlocal nomodifiable
endfunction

function! s:ClassExist(word)
    silent let s:buffer = systemlist('perldoc -otext -T ' . a:word)
    let s:last_class= !v:shell_error
    return !v:shell_error
endfunction

function! s:FuncExist(word)
    silent let s:buffer = systemlist('perldoc -otext -f ' . a:word)
    return !v:shell_error
endfunction

function! s:VarsExist(word)
    silent let s:buffer = systemlist('perldoc -otext -v ' . shellescape(a:word))
    return !v:shell_error
endfunction

function! s:Perldoc(...)
    let word = join(a:000, ' ')
    if !strlen(word)
        let word = expand('<cword>')
    endif
    let word = substitute(word, '^\(.*[^:]\)::$', '\1', '')
    call s:PerldocWord(word)
endfunction

let s:perlpath = ''
function! s:PerldocComplete(ArgLead, CmdLine, CursorPos)
    if len(s:perlpath) == 0
        try
            let s:perlpath = system('perl -e ' . shellescape("print join(q/,/,@INC)"))
        catch /E145:/
            let s:perlpath = ".,,"
        endtry
    endif
    let ret = {}
    for p in split(s:perlpath, ',')
        for i in split(globpath(p, substitute(a:ArgLead, '::', '/', 'g').'*'), "\n")
            if isdirectory(i)
                let i .= '/'
            elseif i !~ '\.pm$'
                continue
            endif
            let i = substitute(substitute(i[len(p)+1:], '[\\/]', '::', 'g'), '\.pm$', '', 'g')
            let ret[i] = i
        endfor
    endfor
    return sort(keys(ret))
endfunction

command! -nargs=* -complete=customlist,s:PerldocComplete Perldoc :call s:Perldoc(<q-args>)
nnoremap <silent> <Plug>(perldoc) :<C-u>Perldoc<CR>

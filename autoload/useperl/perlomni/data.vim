fun! s:build_hash(list,menu)
  return map( a:list , '{ "word": v:val , "menu": "'. a:menu .'" }' )
endf

let s:p5bfunctions =
      \ s:build_hash( split('abs accept alarm atan2 bind binmode bless break caller chdir chmod chomp chop chown chr chroot close closedir connect continue cos crypt dbmclose dbmopen defined delete die do dump each endgrent endhostent endnetent endprotoent endpwent endservent eof eval exec exists exit exp fcntl fileno flock fork format formline getc getgrent getgrgid getgrnam gethostbyaddr gethostbyname gethostent getlogin getnetbyaddr getnetbyname getnetent getpeername getpgrp getppid getpriority getprotobyname getprotobynumber getprotoent getpwent getpwnam getpwuid getservbyname getservbyport getservent getsockname getsockopt glob gmtime goto grep hex import index int ioctl join keys kill last lc lcfirst length link listen local localtime lock log lstat m map mkdir msgctl msgget msgrcv msgsnd my next no oct open opendir ord our pack package pipe pop pos print printf prototype push q qq qr quotemeta qw qx rand read readdir readline readlink readpipe recv redo ref rename require reset return reverse rewinddir rindex rmdir s say scalar seek seekdir select semctl semget semop send setgrent sethostent setnetent setpgrp setpriority setprotoent setpwent setservent setsockopt shift shmctl shmget shmread shmwrite shutdown sin sleep socket socketpair sort splice split sprintf sqrt srand stat state study sub substr symlink syscall sysopen sysread sysseek system syswrite tell telldir tie tied time times tr truncate uc ucfirst umask undef unlink unpack unshift untie use utime values vec wait waitpid wantarray warn write y'),
      \ 'built-in' )

" XXX: should be automatically build by script ( utils/build_mi_args.pl )
let s:p5_mi_export =
    \ s:build_hash( split( 'resources install_as_vendor keywords bundles write_mymeta_json recommends sign no_index perl_version_from name install_requires provides add_metadata author module_name repository version author_from test_requires_from configure_requires perl_version install_as_cpan all_from version_from feature read write_mymeta_yaml write install_as_site authors requires_from bugtracker_from auto_provides homepage abstract abstract_from test_requires distribution_type installdirs bugtracker dynamic_config license_from requires install_as_core features name_from license import build_requires tests' ) ,
    \ 'Module::Install::Metadata' )

function! useperl#perlomni#data#struct() abort "{{{
    return s:
endfunction "}}}

let s:static = {}
let s:pack = {}
function! useperl#perlomni#data#pack() abort "{{{
    return s:pack
endfunction "}}}

" GetData: 
function! s:GetData(key) abort "{{{
    let l:dot = stridx(a:key, '.')
    if l:dot > -1
        let l:file = strpart(a:key, 0, l:dot)
        let l:key = strpart(a:key, l:dot + 1)
    else
        let l:file = a:key
        let l:key = ''
    endif

    if !has_key(s:static, l:file)
        call s:readpod(l:file)
    endif

    if has_key(s:static, l:file)
        if empty(l:key)
            return s:static[l:file]
        else
            return get(s:static[l:file], l:key, [])
        endif
    else
        :DLOG 'fails to read pod data file: ' . l:file
        return []
    endif
endfunction "}}}
let s:pack.GetData = function('s:GetData')

" readpod: 
function! s:readpod(file) abort "{{{
    if a:file !~ '^[\w]'
        :DLOG 'invalid file name: ' . a:file
        return
    endif

    let l:file = useperl#plugin#dir() . '/perlomni/data/' . a:file . '.pod'
    if !filereadable(l:file)
        let l:dir = useperl#plugin#dir() . '/perlomni/data'
        let l:cmd = printf('make %s -C "%s"', a:file . '.pod', l:dir)
        :DLOG 'will build data $' . l:cmd
        call system(l:cmd)
        if v:shell_error
            :DLOG 'shell make error'
            return
        endif
    endif
    if !filereadable(l:file)
        :ELOG 'file isnot readable: ' . l:file
    endif

    let l:lsConent = readfile(l:file)
    if !empty(l:lsConent)
        let l:result = s:parsepod(l:lsConent)
        if empty(l:result)
            :DLOG 'seams read in empty data?'
            return
        endif
        let s:static[a:file] = l:result
    endif
endfunction "}}}

" parsepod: 
function! s:parsepod(list) abort "{{{
    if empty(a:list) || type(a:list) != type([])
        return {}
    endif

    let l:data = {}
    let l:key = ''
    let l:start = -1
    let l:stop = -1

    let l:iend = len(a:list)
    let l:idx = 0
    while l:idx < l:iend
        let l:line = a:list[l:idx]
        let l:idx += 1

        " just reach the end, extract the last item data
        if l:idx >= l:iend
            let l:stop = l:idx - 1
            if l:line =~? '^=item\s\+'
                let l:stop -= 1
            endif
            if !empty(l:key) && l:start >= 0
                let l:data[l:key] = s:slicepod(a:list, l:start, l:stop)
            else
                " no =item, simple list instead
                let l:key = 'list'
                let l:data[l:key] = s:slicepod(a:list, 0, l:stop)
            endif
            break
        endif

        if l:line !~? '^=item\s\+'
            continue
        endif

        let l:words = split(l:line)
        if len(l:words) < 2
            continue
        endif
        call remove(l:words, 0) " drop =item

        if !empty(l:key) && l:start >=0
            let l:stop = l:idx - 2 " l:idx has move next to =item line
            let l:data[l:key] = s:slicepod(a:list, l:start, l:stop)
        endif

        " switch to new item data
        let l:key = l:words[1]
        let l:start = l:idx
        let l:stop = l:start
    endwhile

    return l:data
endfunction "}}}

" slicepod: return a sublist btween in [first, last], 
" and trim empty line in tow ends
function! s:slicepod(list, first, last) abort "{{{
    if a:last < a:first
        :DLOG 'invalid empty data? a:last < a:first'
        return []
    endif

    let l:first = a:first
    let l:last = a:last
    let l:iend = len(a:list)
    while l:first <= l:last && l:first < l:iend && empty(a:list[l:first])
        let l:first += 1
    endwhile
    while l:last >= l:first && l:last >= 0 && empty(a:list[l:last])
        let l:last -= 1
    endwhile

    if l:last < l:first
        :DLOG 'invalid empty data? a:last < a:first'
        return []
    endif

    return a:list[l:first : l:last]
endfunction "}}}

" vcs:type: git
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim


let s:type = {
\   'name': 'git',
\   'cached_status': {},
\ }



function! s:type.detect(file)
  return finddir('.git', fnamemodify(a:file, ':p:h') . ';') != ''
endfunction

function! s:type.root(...)
  return fnamemodify(finddir('.git',
        \ (a:0 > 1 ? fnamemodify(a:1, ':p:h') : '') . ';'),
  \                  ':p:h:h')
endfunction

function! s:type.repository(...)
  return fnamemodify(finddir('.git',
        \ (a:0 > 1 ? fnamemodify(a:1, ':p:h') : '') . ';'),
  \                  ':p:h')
endfunction

function! s:type.repository_name()"{{{
  return fnamemodify(self.root(), ':t')
endfunction"}}}

function! s:type.relative_path(file)"{{{
  return fnamemodify(a:file, ':p')[len(self.root())+1 : -2]
endfunction"}}}

function! s:type.current_branch()"{{{
  let root = self.root()
  if root == '' || !filereadable(root . '/.git/HEAD')
    return ''
  endif

  let lines = readfile(root . '/.git/HEAD')
  if empty(l:lines)
    return ''
  else
    return matchstr(lines[0], 'refs/heads/\zs.\+$')
  endif
endfunction"}}}

function! s:type.is_synced()"{{{
  let root = self.root()
  if root == ''
    return 0
  endif

  let head = self.run('rev-parse', 'HEAD')
  " Chomp.
  if head =~ '\r\?\n'
    let head = matchstr(head, '^.*\ze\r\?\n')
  endif

  for remote in split(self.run('rev-parse',
        \ '--remotes', '--branches'), '\r\?\n')
    if head ==# remote
      return 0
    endif
  endfor

  return 1
endfunction"}}}


function! s:type.add(files)
  return self.run('add', a:files)
endfunction

function! s:type.rm(files)
  return self.run('rm', a:files)
endfunction

function! s:type.cat(file, rev)
  " TODO: handle the error
  return self.runf(a:file, ['show', a:rev . ':' . a:file])
endfunction

function! s:type.commit(info, ...)
  let args = ['commit', '-a']
  if has_key(a:info, 'msgfile')
    let args += ['-F', a:info.msgfile]
  endif
  if has_key(a:info, 'date')
    if type(a:info.date) == type(0)
      let date = strftime('%Y-%m-%dT%H:%M:%S', a:info.date)
    else
      let date = a:info.date
    endif
    call add(args, '--date=' . date)
  endif
  if a:0 && type(a:1) == type([])
    let args += a:1
  endif
  let res = self.run(args)
  return res
endfunction

function! s:type.reset(files)
  return self.run('reset', 'HEAD', '--', a:files)
endfunction

function! s:type.diff(...)
  let files = get(a:000, 0, [])
  let rev = a:000[1:]
  if empty(rev)
    let rev = ['HEAD']
  endif
  return self.runf(get(files, 0, ''), 'diff', rev, '--', files)
endfunction

function! s:type.revno(rev)
  return a:rev
endfunction

function! s:type.run(...)
  let cmd = has_key(self, 'cmd') ? self.cmd : g:vcs#type#git#cmd
  return vcs#system([cmd, a:000])
endfunction

function! s:type.runf(file, ...)
  let root = self.root(a:file != '' ? a:file : expand('%:p:h'))
  return self.run(a:000)
endfunction

let s:status_char = {
\   ' ': "unmodified",
\   'A': "added",
\   'C': "conflicted",
\   'D': "deleted",
\   'I': "ignored",
\   'M': "modified",
\   'R': "renamed",
\   '?': "untracked",
\ }
function! s:type.status(...)
  let files = a:0 ? a:1 : []
  return s:get_status(self, files, 0)
endfunction
function! s:type.unstaged_status(...)
  let files = a:0 ? a:1 : []
  return s:get_status(self, files, 1)
endfunction

function! s:get_status(self, files, is_unstaged)
  let status = {}
  let base = empty(a:files) ? '' : a:files[0]
  let res = a:self.runf(base, 'status', '--short', '--', a:files)

  for i in split(res, "\n")
    let [x, y, file] = [i[0], i[1], i[3:]]
    if !a:is_unstaged && x == '?'
      " untracked files.
      continue
    endif

    let status[file] = a:is_unstaged ? y : x
  endfor

  let ignored = a:self.runf(base, 'ls-files',
        \                      '--exclude-standard', '-o', '-i', '--', a:files)
  for i in split(ignored, "\n")
    let status[i] = 'I'
  endfor
  return map(status, 'get(s:status_char, v:val, " ")')
endfunction


function! vcs#type#git#load()
  return copy(s:type)
endfunction



if !exists('g:vcs#type#git#cmd')
  let g:vcs#type#git#cmd = 'git'
endif



let &cpo = s:save_cpo
unlet s:save_cpo

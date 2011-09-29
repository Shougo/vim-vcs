" vcs:type: mercurial
" Version: 0.1.0
" Author : choplin <choplin.public+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim


let s:type = {
\   'name': 'mercurial',
\   'cached_status': {},
\ }



function! s:type.detect(file)
  return finddir('.hg', fnamemodify(a:file, ':p:h') . ';') != ''
endfunction

function! s:type.root(...)
  return fnamemodify(finddir('.hg',
        \ (a:0 > 1 ? fnamemodify(a:1, ':p:h') : '') . ';'),
  \                  ':p:h:h')
endfunction

function! s:type.repository(...)
  return fnamemodify(finddir('.hg',
        \ (a:0 > 1 ? fnamemodify(a:1, ':p:h') : '') . ';'),
  \                  ':p:h')
endfunction

function! s:type.repository_name()"{{{
  return fnamemodify(self.root(), ':t')
endfunction"}}}

function! s:type.relative_path(file)"{{{
  return fnamemodify(a:file, ':p')[len(self.root())+1 : -1]
endfunction"}}}

function! s:type.current_branch()"{{{
  let root = self.root()
  if root == '' || !filereadable(root . '/.hg/branch')
    return ''
  endif

  let lines = readfile(root . '/.hg/branch')
  if empty(l:lines)
    return ''
  else
    return lines[0]
  endif
endfunction"}}}

function! s:type.is_synced()"{{{
  let root = self.root()
  if root == ''
    return 0
  endif

  for line in split(self.run('summary', '--remote'), '\r\?\n')
    if line =~ 'remote'
      if line =~ 'synced'
        return 1
      else
        return 0
      endif
    endif
  endfor

  " consider repository as syned if no remote repository is found
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
  return self.runf(a:file, 'cat', a:file, '-r', a:rev)
endfunction

function! s:type.commit(info, ...)
  let args = ['commit']
  if has_key(a:info, 'msgfile')
    let args += ['-l', a:info.msgfile]
  endif
  if has_key(a:info, 'date')
    if type(a:info.date) == type(0)
      let date = strftime('%Y-%m-%d %h:%m:%S', a:info.date)
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
  return self.run('forget', a:files)
endfunction

function! s:type.diff(...)
  let args = ['diff']
  if a:0 >= 2
    let args += ['-r', a:2]
  endif
  if a:0 >= 3
    let args += ['-r', a:3]
  endif
  let files = get(a:000, 0, [])
  let args += files
  return self.runf(get(files, 0, ''), args)
endfunction

function! s:type.revno(rev)
  return a:rev
endfunction

function! s:type.run(...)
  let cmd = has_key(self, 'cmd') ? self.cmd : g:vcs#type#mercurial#cmd
  return vcs#system([cmd, a:000])
endfunction

function! s:type.runf(file, ...)
  let root = self.root(a:file != '' ? a:file : expand('%:p:h'))
  return call(self.run, a:000, self)
endfunction

let s:mercurial_status_char = {
\   'M': "modified",
\   'A': "added",
\   'R': "removed",
\   'C': "clean",
\   '!': "missing (deleted by non-hg command, but still tracked)",
\   '?': "not tracked",
\   'I': "ignored",
\ }
function! s:type.status(...)
  let files = a:0 ? a:1 : []
  let status = {}
  let base = empty(files) ? '' : files[0]
  let res = self.runf(base, 'status', '-A', files)

  for i in split(res, "\n")
    let [code, file] = [i[0], i[2:]]

    if has_key(s:mercurial_status_char, code)
      let status[file] = code
    endif
  endfor

  return map(status, 'get(s:mercurial_status_char, v:val, " ")')
endfunction

function! vcs#type#mercurial#load()
  return copy(s:type)
endfunction

if !exists('g:vcs#type#mercurial#cmd')
  let g:vcs#type#mercurial#cmd = 'hg'
endif

let &cpo = s:save_cpo
unlet s:save_cpo

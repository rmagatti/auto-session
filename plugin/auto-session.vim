if exists('g:loaded_auto_session') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

" Available commands
command! SaveSession lua require'auto-session'.SaveSession()
command! RestoreSession lua require'auto-session'.RestoreSession()

augroup autosession
  autocmd!
  autocmd VimLeave * lua require'auto-session'.AutoSaveSession()
  autocmd VimEnter * nested lua require'auto-session'.AutoRestoreSession()
augroup end

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded_auto_session = 1

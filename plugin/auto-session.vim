if exists('g:loaded_auto_session') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

let LuaSaveSession = luaeval('require("auto-session").SaveSession')
let LuaRestoreSession = luaeval('require("auto-session").RestoreSession')

" Available commands
command! -nargs=* SaveSession call LuaSaveSession(expand('<args>'))
command! -nargs=* RestoreSession call LuaRestoreSession(expand('<args>'))

augroup autosession
  autocmd!
  autocmd VimLeave * lua require'auto-session'.AutoSaveSession()
  autocmd VimEnter * nested lua require'auto-session'.AutoRestoreSession()
augroup end

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded_auto_session = 1

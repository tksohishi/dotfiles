" .gvimrc

" Macvim Setting
if has('gui_macvim')

  " {{{ Basic
  set transparency=5
  set columns=180          " Window size(width)
  set lines=50             " Window size(height)
  colorscheme molokai      " molokai
  set guifont=Monaco:h13   " Font Monaco 13pt
  set cmdheight=2
  " No toolbar, No menubar, No scrollbars
  set guioptions-=T
  set guioptions-=m
  set guioptions-=l
  set guioptions-=L
  set guioptions-=r
  set guioptions-=R
  " }}}

  " {{{ Commands
  " Large font
  command! GuiLargeFont set guifont=Monaco:h48 cmdheight=1
  command! GuiStandardFont set guifont=Monaco:h13 cmdheight=2
  " }}}

endif

" vim:set tabstop=2 shiftwidth=2 expandtab foldmethod=marker nowrap:

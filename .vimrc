" .vimrc
" ref: https://github.com/niw/profiles/blob/master/.vimrc

""{{{ Initialize

if !exists('s:loaded_vimrc')
  " Don't reset twice on reloading, 'compatible' has many side effects.
  set nocompatible
endif

" We have now 64 bit Windows.
let s:has_win = has('win32') || has('win64')

" Reset all autocmd defined in this file.
augroup MyAutoCommands
  autocmd!
augroup END

"}}}

" {{{ Vundle
filetype off

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" let Vundle manage vundle itself
Bundle 'gmarik/vundle'

" plugin
Bundle 'Shougo/unite.vim'
Bundle 'h1mesuke/unite-outline'
Bundle 'ujihisa/unite-colorscheme'
Bundle 'ujihisa/unite-font'
Bundle 'tsukkee/unite-help'
Bundle 'tyru/caw.vim'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-rails'
Bundle 'mattn/zencoding-vim'
Bundle 'vim-ruby/vim-ruby'
Bundle 'thinca/vim-ref'
Bundle 'thinca/vim-quickrun'
Bundle 'Shougo/neocomplcache'
Bundle 'ujihisa/neco-look'
Bundle 'tyru/open-browser.vim'
Bundle 'thinca/vim-poslist'
Bundle 'sudo.vim'

" syntax highlight
Bundle 'cucumber.zip'
Bundle 'Puppet-Syntax-Highlighting'
Bundle 'plasticboy/vim-markdown'
Bundle 'jQuery'
Bundle 'nginx.vim'
Bundle 'mikbe/rspec.vim'
Bundle 'othree/html5.vim'
Bundle 'hail2u/vim-css3-syntax'

" colorscheme
Bundle 'molokai'
Bundle 'jpo/vim-railscasts-theme'
Bundle 'altercation/vim-colors-solarized'
Bundle 'wombat256.vim'

filetype plugin indent on

" }}}

"{{{ Encodings and Japanese

function! s:SetEncoding() "{{{
  " As default, we're using UTF-8, of course.
  set encoding=utf-8

  " Done by here, if it's MacVim which can't change &termencoding.
  if has('gui_macvim')
    return
  endif

  " Using &encoding as default.
  set termencoding=
  " If LANG shows EUC or Shift-JIS, use it for termencoding.
  if $LANG =~# 'eucJP'
    set termencoding=euc-jp
  elseif $LANG =~# 'SJIS'
    set termencoding=cp932
  endif

  " On Windows, we need to set encoding=japan or force to use cp932.
  " Not tested yet because I'm not using Windows.
  if !has('gui_running') && (&term == 'win32' || &term == 'win64')
    set termencoding=cp932
    set encoding=japan
  elseif has('gui_running') && s:has_win
    set termencoding=cp932
  endif
endfunction "}}}

function! s:SetFileEncodings() "{{{
  if !has('iconv')
    return
  endif

  let enc_eucjp = 'euc-jp'
  let enc_jis = 'iso-2022-jp'

  " Check availability of iconv library.
  " Try converting the cahrs defined in EUC JIS X 0213 to CP932
  " to make sure iconv supprts JIS X 0213 or not.
  if iconv("\x87\x64\x87\x6a", 'cp932', 'euc-jisx0213') ==# "\xad\xc5\xad\xcb"
    let enc_eucjp = 'euc-jisx0213,euc-jp'
    let enc_jis = 'iso-2022-jp-3'
  endif

  let value = 'ucs-bom'
  if &encoding !=# 'utf-8'
    let value = value . ',' . 'ucs-2le' . ',' . 'ucs-2'
  endif

  let value = value . ',' . enc_jis

  if &encoding ==# 'utf-8'
    let value = value . ',' . enc_eucjp . ',' . 'cp932'
  elseif &encoding ==# 'euc-jp' || &encoding ==# 'euc-jisx0213'
  " Reset existing values
    let value = enc_eucjp . ',' . 'utf-8' . ',' . 'cp932'
  else " assuming &encoding ==# 'cp932'
    let value = value . ',' . 'utf-8' . ',' . enc_eucjp
  endif
  let value = value . ',' . &encoding

  if has('guess_encode')
    let value = 'guess' . ',' . value
  endif

  let &fileencodings = value
endfunction "}}}

" Make sure the file is not including any Japanese in ISO-2022-JP, use encoding for fileencoding.
" https://github.com/Shougo/shougo-s-github/blob/master/vim/.vimrc
function! s:SetFileEncoding() "{{{
  if &fileencoding =~# 'iso-2022-jp' && search("[^\x01-\x7e]", 'n') == 0
    let &fileencoding = &encoding
  endif
endfunction "}}}

call s:SetEncoding()
call s:SetFileEncodings()
autocmd MyAutoCommands BufReadPost * call <SID>SetFileEncoding()

" Address the issue for using □ or ●.
" NOTE We also need to apply some patch for Mac OS X Terminal.app
set ambiwidth=double

" Settings for Input Methods
if has('keymap')
  set iminsert=0 imsearch=0
endif

"}}}

" {{{ Global Setting

" Sound
set vb t_vb=       " ビープをならさない

" Tab
set tabstop=4      " Tab文字を画面上で何文字分に展開するか
set shiftwidth=4   " cindentやautoindent時に挿入されるインデントの幅
set softtabstop=0  " Tabキー押し下げ時の挿入される空白の量，0の場合はtabstopと同じ，BSにも影響する
set noexpandtab    " Tab文字の代わりにスペースを入力しない
set smarttab       " 行頭の余白内で Tab を打ち込むと、'shiftwidth' の数だけインデント

" Indent
set autoindent     " 新しい行のインデントを現在行と同じにする
set smartindent    " 新しい行を作った時高度な自動インデントを行う

" Input
set backspace=indent,eol,start " バックスペースでなんでも消せるように
set formatoptions=lmoq         " 整形オプション，マルチバイト系を追加
set imdisable                  " 日本語入力OFF

" Search
set wrapscan   " 最後まで検索したら先頭へ戻る
set ignorecase " 大文字小文字無視
set smartcase  " 大文字ではじめたら大文字小文字無視しない
set incsearch  " インクリメンタルサーチ
set hlsearch   " 検索文字をハイライト

" File
set nobackup        " バックアップ取らない
set nowritebackup   " バックアップ取らない(for crontab)
set autoread        " 他で書き換えられたら自動で読み直す
set noswapfile      " スワップファイル作らない
set hidden          " 編集中でも他のファイルを開けるようにする
set modeline        " Modelineを有効にする
set fileformat=unix
set fileformats=unix,dos,mac

" Displaying
set showmatch         " 括弧の対応をハイライト
set showcmd           " 入力中のコマンドを表示
set number            " 行番号表示
set ruler
set wrap              " 画面幅で折り返す
set list              " 不可視文字表示
set listchars=tab:>.,trail:_,extends:>,precedes:< " 不可視文字の表示形式
set notitle           " タイトル書き換えない

" Moving
set scrolloff=5       " 行送り
set whichwrap=b,s,h,l,<,>,[,] " カーソルを行頭、行末で止まらないようにする

" vim+iTerm2でマウスを使用できるようにする
set mouse=a
set guioptions+=a
set ttymouse=xterm2

" TODO
" vim+iTerm2でCommand-C, Command-Vを有効に

set history=100
set ttyfast
set wildmode=longest,list,full
set completeopt=menuone

" }}}

" {{{ Status Line
set laststatus=2
let &statusline = ''
let &statusline .= '%3n ' " Buffer number
let &statusline .= '%<%f ' " Filename
let &statusline .= '%m%r%h%w' " Modified flag, Readonly flag, Preview flag
let &statusline .= '%{"[" . (&fileencoding != "" ? &fileencoding : &encoding) . "][" . &fileformat . "][" . &filetype . "]"}'
let &statusline .= '%=' " Spaces
let &statusline .= '%{fugitive#statusline()} ' " Git repository status, require vim-fugitive plugin.
" FIXME make sure we can use vim-fugitive or not.
let &statusline .= '%l/%L,%c%V' "Line number/Line total count, Column number, Virtual column number
let &statusline .= '%4P' " Percentage through file of displayed window.
" }}}

" {{{ Colorscheme
if $TERM =~? '256' || has('gui_running')
  colorscheme molokai
else
  colorscheme desert
endif
" }}}

"{{{ Syntax and File Types

" Enable syntax color.
syntax enable
filetype plugin on

augroup MyAutoCommands
  " Disable automatically insert comment.
  " See :help fo-table
  autocmd FileType *                    setlocal formatoptions-=ro | setlocal formatoptions+=mM

  autocmd FileType ruby,eruby,haml      setlocal tabstop=2 shiftwidth=2 expandtab nowrap makeprg=ruby\ -c\ % errorformat=%m\ in\ %f\ on\ line\ %l
  autocmd FileType vim                  setlocal tabstop=2 shiftwidth=2 expandtab nowrap
  autocmd FileType actionscript         setlocal fileencoding=utf-8 tabstop=4 shiftwidth=4 noexpandtab nowrap
  autocmd FileType php                  setlocal tabstop=2 shiftwidth=2 expandtab nowrap
  autocmd FileType python               setlocal tabstop=2 shiftwidth=2 expandtab nowrap omnifunc=pythoncomplete#Complete
  autocmd FileType thrift               setlocal tabstop=2 shiftwidth=2 expandtab nowrap
  autocmd FileType css                  setlocal tabstop=2 shiftwidth=2 expandtab nowrap omnifunc=csscomplete#CompleteCSS
  autocmd FileType html,markdown        setlocal tabstop=2 shiftwidth=2 expandtab nowrap omnifunc=htmlcomplete#CompleteTags
  autocmd FileType javascript           setlocal tabstop=2 shiftwidth=2 expandtab nowrap omnifunc=javascriptcomplete#CompleteJS
  autocmd FileType xml                  setlocal omnifunc=xmlcomplete#CompleteTags

  " Unite
  " ウィンドウを横分割して開く
  autocmd FileType unite nnoremap <silent> <buffer> <expr> <C-j> unite#do_action('split')
  autocmd FileType unite inoremap <silent> <buffer> <expr> <C-j> unite#do_action('split')
  " ウィンドウを縦分割して開く
  autocmd FileType unite nnoremap <silent> <buffer> <expr> <C-k> unite#do_action('vsplit')
  autocmd FileType unite inoremap <silent> <buffer> <expr> <C-k> unite#do_action('vsplit')

  " File Types
  autocmd BufNewFile,BufRead *.as       setlocal filetype=actionscript tabstop=2 shiftwidth=2 expandtab nowrap
  autocmd BufNewFile,BufRead *.rl       setlocal filetype=ragel
  autocmd BufNewFile,BufRead *.srt      setlocal filetype=srt
  autocmd BufNewFile,BufRead nginx.*    setlocal filetype=nginx
  autocmd BufNewFile,BufRead Portfile   setlocal filetype=macports
  autocmd BufNewFile,BufRead *.vcf      setlocal filetype=vcard
  autocmd BufNewFile,BufRead *.module   setlocal filetype=php
  autocmd BufNewFile,BufRead *.mustache setlocal syntax=mustache
  autocmd BufNewFile,BufRead *.json     setlocal filetype=json
  autocmd BufNewFile,BufRead *.pp       setlocal filetype=puppet
  autocmd BufNewFile,BufRead *.mm       setlocal filetype=cpp
  autocmd BufNewFile,BufRead *.thrift   setlocal filetype=thrift
  autocmd BufNewFile,BufRead *.psgi     setlocal filetype=perl
  autocmd BufNewFile,BufRead *.go       setlocal filetype=go
  autocmd BufNewFile,BufRead *.mkd      setlocal filetype=mkd
  autocmd BufNewFile,BufRead *.md       setlocal filetype=mkd
  autocmd BufNewFile,BufRead *.markdown setlocal filetype=mkd
  autocmd BufNewFile,BufRead *.mdown    setlocal filetype=mkd
  autocmd BufNewFile,BufRead *.mkdn     setlocal filetype=mkd
  autocmd BufNewFile,BufRead *.ru       setlocal filetype=ruby
augroup END

"  *.m is not MATLAB file, but Objective-C
let g:filetype_m = 'objc'

" }}}

" {{{ Key Mappings

" {{{ Basic Moving/Search
" Move cursor by display line
noremap j gj
noremap k gk
noremap gj j
noremap gk k

" Centering search result
nnoremap n nzz
nnoremap N Nzz
nnoremap * *zz
nnoremap # #zz
nnoremap g* g*zz
nnoremap g# g#zz
" }}}

" {{{ Leader
" Define <Leader>, <LocalLeader>
let mapleader=","
let maplocalleader="_"

" Disable <Leader>, <LocalLeader> to avoid unexpected behavior.
noremap <Leader> <Nop>
noremap <LocalLeader> <Nop>
" }}}

" {{{ q, Q, K Mapping Change
" Reserve q for prefix key then assign Q for original actions.
" Q is for Ex-mode which we don't need to use.
nnoremap q <Nop>
nnoremap Q q

" Avoid run K mistakenly with C-k, remap K to qK
nnoremap K <Nop>
nnoremap qK K
" }}}

" {{{ [Space]
nmap <Space> [Space]
xmap <Space> [Space]
nnoremap [Space] <Nop>
xnoremap [Space] <Nop>
" }}}

" {{{ Grep/Lookup Help
" Operation for the words under the cursor or the visual region
function! s:CommandWithVisualRegionString(cmd) "{{{
  let reg = getreg('a')
  let regtype = getregtype('a')
  silent normal! gv"ay
  let selected = @a
  call setreg('a', reg, regtype)
  execute a:cmd . ' ' . selected
endfunction "}}}

" Grep
nnoremap <silent> gr :<C-u>Grep<Space><C-r><C-w><CR>
xnoremap <silent> gr :<C-u>call <SID>CommandWithVisualRegionString('Grep')<CR>

" Help
nnoremap <silent> [Space]h :<C-u>help<Space><C-r><C-w><CR>
xnoremap <silent> [Space]h :<C-u>call <SID>CommandWithVisualRegionString('help')<CR>
" }}}

" {{{ Buffer
" Use [Space] for Buffer manipulation
nmap [Space] [Buffer]
xmap [Space] [Buffer]

function! s:NextNormalBuffer(loop) "{{{
  let buffer_num = bufnr('%')
  let last_buffer_num = bufnr('$')

  let next_buffer_num = buffer_num
  while 1
    if next_buffer_num == last_buffer_num
      if a:loop
        let next_buffer_num = 1
      else
        break
      endif
    else
      let next_buffer_num = next_buffer_num + 1
    endif
    if next_buffer_num == buffer_num
      break
    endif
    if ! buflisted(next_buffer_num)
      continue
    endif
    if getbufvar(next_buffer_num, '&buftype') == ""
      return next_buffer_num
      break
    endif
  endwhile
  return 0
endfunction "}}}

function! s:OpenNextNormalBuffer(loop) "{{{
  if &buftype == ""
    let buffer_num = s:NextNormalBuffer(a:loop)
    if buffer_num
      execute "buffer" buffer_num
    endif
  endif
endfunction "}}}

function! s:PrevNormalBuffer(loop) "{{{
  let buffer_num = bufnr('%')
  let last_buffer_num = bufnr('$')

  let prev_buffer_num = buffer_num
  while 1
    if prev_buffer_num == 1
      if a:loop
        let prev_buffer_num = last_buffer_num
      else
        break
      endif
    else
      let prev_buffer_num = prev_buffer_num - 1
    endif
    if prev_buffer_num == buffer_num
      break
    endif
    if ! buflisted(prev_buffer_num)
      continue
    endif
    if getbufvar(prev_buffer_num, '&buftype') == ""
      return prev_buffer_num
      break
    endif
  endwhile
  return 0
endfunction "}}}

function! s:OpenPrevNormalBuffer(loop) "{{{
  if &buftype == ""
    let buffer_num = s:PrevNormalBuffer(a:loop)
    if buffer_num
      execute "buffer" buffer_num
    endif
  endif
endfunction "}}}

noremap <silent> [Buffer]P :<C-u>call <SID>OpenPrevNormalBuffer(0)<CR>
noremap <silent> [Buffer]p :<C-u>call <SID>OpenPrevNormalBuffer(1)<CR>
noremap <silent> [Buffer]N :<C-u>call <SID>OpenNextNormalBuffer(0)<CR>
noremap <silent> [Buffer]n :<C-u>call <SID>OpenNextNormalBuffer(1)<CR>
" }}}

" Tab {{{
" User t for Tab manipulation
nmap t [Tab]
nnoremap [Tab] <Nop>

function! s:MapTabNextWithCount() " {{{
  let tab_count = 1
  while tab_count < 10
    execute printf("noremap <silent> [Tab]%s :tabnext %s<CR>", tab_count, tab_count)
    let tab_count = tab_count + 1
  endwhile
endfunction " }}}

nnoremap <silent> [Tab]c :<C-u>tabnew<CR>
nnoremap <silent> [Tab]q :<C-u>tabclose<CR>
nnoremap <silent> [Tab]n :<C-u>tabnext<CR>
nnoremap <silent> [Tab]p :<C-u>tabprev<CR>

call s:MapTabNextWithCount()
"}}}

" {{{ Window * not used currently
" Use s for window manipulation
" nmap s [Window]
" nnoremap [Window] <Nop>

" nnoremap [Window]j <C-W>j
" nnoremap [Window]k <C-W>k
" nnoremap [Window]h <C-W>h
" nnoremap [Window]l <C-W>l

" nnoremap [Window]v <C-w>v
" " Centering cursor after splitting window
" nnoremap [Window]s <C-w>szz

" nnoremap [Window]q :<C-u>quit<CR>
" nnoremap [Window]d :<C-u>Bdelete<CR>

" nnoremap [Window]= <C-w>=
" nnoremap [Window], <C-w><
" nnoremap [Window]. <C-w>>
" nnoremap [Window]] <C-w>+
" nnoremap [Window][ <C-w>-
"}}}

" {{{ QuickFix
function! s:OpenQuickFixWithSyntex(syntax) " {{{
  let g:last_quick_fix_syntax = a:syntax
  execute "copen"
  execute "syntax match Underlined '\\v" . a:syntax . "' display containedin=ALL"
  call feedkeys("\<C-w>J", "n")
endfunction

function! s:OpenQuickFix()
  if exists('g:last_quick_fix_syntax')
    call s:OpenQuickFixWithSyntex(g:last_quick_fix_syntax)
  else
    execute "copen"
  endif
endfunction " }}}

nnoremap <silent> qq :call <SID>OpenQuickFix()<CR>
nnoremap <silent> qw :<C-u>cclose<CR>
"}}}

" Disable Highlight Search
nnoremap <Esc><Esc> :<C-u>set nohlsearch<Cr>
nnoremap / :<C-u>set hlsearch<Return>/
nnoremap ? :<C-u>set hlsearch<Return>?
nnoremap * :<C-u>set hlsearch<Return>*
nnoremap # :<C-u>set hlsearch<Return>#

" Make
noremap <silent> [Space], :<C-u>make<CR>

" vimrc edit/reload
" Quick edit and reload .vimrc
nnoremap [Space].  :<C-u>edit $MYVIMRC<CR>
nnoremap [Space]s. :<C-u>source $MYVIMRC<CR>

" Run shell
nnoremap <silent> [Space]; :<C-u>shell<CR>
nnoremap <silent> [Space]: :<C-u>shell<CR>

" Fold vim comment
nnoremap <silent> [Space]a za
nnoremap <silent> [Space]A zA

" Easy update
nnoremap <silent> [Space]w :<C-u>update<CR>
" }}}

" {{{ Commands

" Open as UTF-8
command! Utf8 edit ++enc=utf-8

" Change file name editing
command! -nargs=1 -complete=file Rename file <args>|call delete(expand('#'))

" TabpageCD (Modified.)
" See https://gist.github.com/604543/
"{{{
function! s:StoreTabpageCD()
  let t:cwd = getcwd()
endfunction!

function! s:RestoreTabpageCD()
  if exists('t:cwd') && !isdirectory(t:cwd)
    unlet t:cwd
  endif
  if !exists('t:cwd')
    let t:cwd = getcwd()
  endif
  execute 'cd' fnameescape(expand(t:cwd))
endfunction

augroup MyAutoCommands
  autocmd TabLeave * call <SID>StoreTabpageCD()
  autocmd TabEnter * call <SID>RestoreTabpageCD()
augroup END
"}}}

" Keep no end of line
" See http://vim.wikia.com/wiki/Preserve_missing_end-of-line_at_end_of_text_files
"{{{
function! s:SetBinaryForNoeol()
  let g:save_binary_for_noeol = &binary
  if ! &endofline && ! &binary
    setlocal binary
    if &fileformat == "dos"
      silent 1,$-1s/$/\="\\".nr2char(13)
    endif
  endif
endfunction

function! s:RestoreBinaryForNoeol()
  if ! &endofline && ! g:save_binary_for_noeol
    if &fileformat == "dos"
      silent 1,$-1s/\r$/
    endif
    setlocal nobinary
  endif
endfunction

augroup MyAutoCommands
  autocmd BufWritePre  * :call <SID>SetBinaryForNoeol()
  autocmd BufWritePost * :call <SID>RestoreBinaryForNoeol()
augroup END
"}}}

" }}}

" {{{ Platform Dependents
" I don't want to use Japanese menu on MacVim
if has("gui_macvim")
  set langmenu=none
endif
" }}}

" {{{ Vim Plugin Setting

" {{{ Git Plugin (Standard Plugin)
autocmd MyAutoCommands FileType gitcommit DiffGitCached
" }}}

" {{{ unite.vim
" https://github.com/Shougo/unite.vim
nnoremap <silent> ;; :<C-u>Unite buffer -toggle<CR>
"nnoremap <silent> :: :<C-u>UniteWithBufferDir -buffer-name=files buffer file_mru bookmark file file_rec -toggle<CR>
nnoremap <silent> ;b :<C-u>Unite buffer<CR>
nnoremap <silent> ;f :<C-u>Unite file<CR>
nnoremap <silent> ;r :<C-u>Unite file_rec<CR>
nnoremap <silent> ;o :<C-u>Unite outline<CR>
nnoremap <silent> ;c :<C-u>Unite colorscheme -auto-preview<CR>
nnoremap <silent> ;m :<C-u>Unite file_mru -winwidth=90<CR>
nnoremap <silent> ;h :<C-u>Unite help<CR>

let g:unite_enable_split_vertically = 1
let g:unite_winwidth=70
let g:unite_split_rule='botright'
let g:unite_source_file_mru_time_format = '%D %H:%M '
let g:unite_source_file_rec_ignore_pattern = 'phpdoc\|\%(^\|/\)\.$\|\~$\|\.\%(o|exe|dll|bak|sw[po]\)$\|\%(^\|/\)\.\%(hg\|git\|bzr\|svn\)\%($\|/\)'

let g:unite_quick_match_table = {
      \'a' : 1, 's' : 2, 'd' : 3, 'f' : 4, 'g' : 5, 'h' : 6, 'j' : 7, 'k' : 8, 'l' : 9, ':' : 10,
      \'q' : 11, 'w' : 12, 'e' : 13, 'r' : 14, 't' : 15, 'y' : 16, 'u' : 17, 'i' : 18, 'o' : 19, 'p' : 20,
      \'1' : 21, '2' : 22, '3' : 23, '4' : 24, '5' : 25, '6' : 26, '7' : 27, '8' : 28, '9' : 29, '0' : 30,
      \}
" }}}

" {{{ neocomplcache.vim

" Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Use camel case completion.
let g:neocomplcache_enable_camel_case_completion = 1
" Use underbar completion.
let g:neocomplcache_enable_underbar_completion = 1
" Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'

" Define dictionary.
let g:neocomplcache_dictionary_filetype_lists = {
    \ 'default' : '',
    \ }

" Define keyword.
if !exists('g:neocomplcache_keyword_patterns')
  let g:neocomplcache_keyword_patterns = {}
endif
let g:neocomplcache_keyword_patterns['default'] = '\h\w*'

" Recommended key-mappings.
" <CR>: close popup and save indent.
inoremap <expr><CR> neocomplcache#smart_close_popup() . "\<CR>"
" <TAB>: completion.
inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
" <C-h>, <BS>: close popup and delete backword char.
inoremap <expr><C-h> neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><BS> neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><C-y> neocomplcache#close_popup()
inoremap <expr><C-e> neocomplcache#cancel_popup()

" Enable heavy omni completion.
if !exists('g:neocomplcache_omni_patterns')
  let g:neocomplcache_omni_patterns = {}
endif
let g:neocomplcache_omni_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
let g:neocomplcache_omni_patterns.c = '\%(\.\|->\)\h\w*'
let g:neocomplcache_omni_patterns.cpp = '\h\w*\%(\.\|->\)\h\w*\|\h\w*::'

" {{{ rsense
let g:rsenseUseOmniFunc = 1
if filereadable(expand('~/.vim/lib/rsense/bin/rsense'))
  let g:rsenseHome = expand('~/vim/lib/rsense')

  let g:neocomplcache_omni_patterns.ruby = '[^. *\t]\.\w*\|\h\w*::'
endif
" }}}

" }}}

" {{{ quickrun.vim
if !exists('g:quickrun_config')
  let g:quickrun_config = {}
endif

augroup TakeshiRSpec
  autocmd!
  autocmd BufWinEnter,BufNewFile *_spec.rb setlocal filetype=ruby.rspec
augroup END

let g:quickrun_config['ruby.rspec'] = {'command': 'rspec'}
" }}}

" {{{ open-browser.vim
nmap <silent> [Space]x <Plug>(openbrowser-smart-search)
vmap <silent> [Space]x <Plug>(openbrowser-smart-search)
" }}}

" {{{ poslist.vim
nmap <C-o> <Plug>(poslist-prev-pos)
nmap <C-i> <Plug>(poslist-next-pos)
" }}}

" }}}

"{{{ Finalize

if !exists('s:loaded_vimrc')
  let s:loaded_vimrc = 1
endif

" See :help secure
set secure

"}}}

" vim: tabstop=2 shiftwidth=2 textwidth=0 expandtab foldmethod=marker nowrap

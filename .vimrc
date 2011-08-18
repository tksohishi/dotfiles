" .vimrc edited by Takeshi Ohishi

"  ref: http://relaxedcolumn.blog8.fc2.com/blog-entry-101.html

" ========== general setting ========== "
" Basic
set nocompatible    " vi互換外す
set t_Co=256        " 256色対応
"colorscheme molokai " molokai http://winterdom.com/2008/08/molokaiforvim
colorscheme desert
syntax enable       " syntaxを有効に

" Vundle
filetype off

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" let Vundle manage vundle
Bundle 'gmarik/vundle'

" plugin
Bundle 'unite.vim'
Bundle 'rails.vim'
Bundle 'surround.vim'
Bundle 'taglist.vim'
Bundle 'quickrun.vim'
Bundle 'matchit.zip'
Bundle 'ZenCoding.vim'
Bundle 'perlomni.vim'
Bundle 'rvm.vim'
Bundle 'scrooloose/nerdcommenter'
Bundle 'vim-ruby/vim-ruby'
Bundle 'thinca/vim-ref'

" syntax highlight
Bundle 'cucumber.zip'
Bundle 'Puppet-Syntax-Highlighting'
Bundle 'css_color.vim'
Bundle 'plasticboy/vim-markdown'
Bundle 'jQuery'
Bundle 'nginx.vim'

" colorscheme
Bundle 'skyfive/molokai'
Bundle 'jpo/vim-railscasts-theme'
Bundle 'altercation/vim-colors-solarized'
Bundle 'wombat256.vim'

filetype plugin indent on

" Basic
let mapleader=","  " <Leader>は','
set vb t_vb=       " ビープをならさない

" Tab
set tabstop=2      " Tab文字を画面上で何文字分に展開するか
set shiftwidth=2   " cindentやautoindent時に挿入されるインデントの幅
set softtabstop=0  " Tabキー押し下げ時の挿入される空白の量，0の場合はtabstopと同じ，BSにも影響する
set expandtab      " Tab文字の代わりにスペースを入力する
set smarttab       " 行頭の余白内で Tab を打ち込むと、'shiftwidth' の数だけインデント

" Indent
set autoindent     " 新しい行のインデントを現在行と同じにする
set smartindent    " 新しい行を作った時高度な自動インデントを行う
autocmd FileType * setlocal formatoptions-=ro " Disable auto-comment

" Input
set backspace=indent,eol,start " バックスペースでなんでも消せるように
set formatoptions=lmoq         " 整形オプション，マルチバイト系を追加
set imdisable                  " 日本語入力OFF(TODO:下の2つ要らないかも)
set iminsert=0                 " Insert mode時にIME OFF
set imsearch=0                 " Search時にIME OFF

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

" Displaying
set showmatch         " 括弧の対応をハイライト
set showcmd           " 入力中のコマンドを表示
set number            " 行番号表示
set wrap              " 画面幅で折り返す
set list              " 不可視文字表示
set listchars=tab:>.,trail:_,extends:>,precedes:< " 不可視文字の表示形式
set notitle           " タイトル書き換えない

" Moving
set scrolloff=5       " 行送り
set whichwrap=b,s,h,l,<,>,[,] " カーソルを行頭、行末で止まらないようにする

" 同じ高さのインデントに移動する
nn <C-k> k:call search ("^". matchstr (getline (line (".")+ 1), '\(\s*\)') ."\\S", 'b')<CR>^
nn <C-j> :call search ("^". matchstr (getline (line (".")), '\(\s*\)') ."\\S")<CR>^

" Encoding
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,iso-2022-jp,euc-jp,cp932
set termencoding=utf-8
set fileformats=unix,dos,mac
" 厳密な文字コード判別
" http://www.kawaz.jp/pukiwiki/?vim#content_1_7
" http://d.hatena.ne.jp/hazy-moon/20061229/1167407073

" Status Line
" ref: http://www.e2esound.com/20080816/entry-id=303#
set laststatus=2
set statusline=%F%m%r%h%w\%=[TYPE=%Y]\[FORMAT=%{&ff}]\[ENC=%{&fileencoding}]\[LOW=%l/%L]\[COL=%v]

" ターミナルでマウスを使用できるようにする
set mouse=a
set guioptions+=a
set ttymouse=xterm2

" ========== vim plugin setting ==========
" NOTE
" Using vundle for management
" The configurtion for that is on the top of this file

" qbuf.vim
"let g:qb_hotkey = ";;"

" taglist.vim(*requires ctags)
" http://nanasi.jp/articles/vim/taglist_vim.html
" http://bit.ly/5maYv5
" https://github.com/vim-scripts/taglist.vim.git
let Tlist_Show_One_File = 1     " 現在編集中のソースのタグしか表示しない
let Tlist_Exit_OnlyWindow = 1   " taglistのウィンドーが最後のウィンドーならばVimを閉じる
let Tlist_Use_Right_Window = 1  " 右側でtaglistのウィンドーを表示
map T :TlistToggle<CR>

" NERD_commenter.vim
" コメントの間にスペースを空ける
let NERDSpaceDelims = 1
" 未対応ファイルタイプのエラーメッセージを表示しない
let NERDShutUp=1

" unite.vim
" https://github.com/Shougo/unite.vim
" http://blog.remora.cx/2010/12/vim-ref-with-unite.html
" 入力モードで開始する
let g:unite_enable_start_insert=1
" バッファ一覧
noremap <C-P> :Unite buffer<CR>
" ファイル一覧
noremap <C-N> :Unite -buffer-name=file file<CR>
" 最近使ったファイルの一覧
noremap <C-Z> :Unite file_mru<CR>
" ウィンドウを分割して開く
au FileType unite nnoremap <silent> <buffer> <expr> <C-J> unite#do_action('split')
au FileType unite inoremap <silent> <buffer> <expr> <C-J> unite#do_action('split')
" ウィンドウを縦に分割して開く
au FileType unite nnoremap <silent> <buffer> <expr> <C-K> unite#do_action('vsplit')
au FileType unite inoremap <silent> <buffer> <expr> <C-K> unite#do_action('vsplit')
" ESCキーを2回押すと終了する
au FileType unite nnoremap <silent> <buffer> <ESC><ESC> :q<CR>
au FileType unite inoremap <silent> <buffer> <ESC><ESC> <ESC>:q<CR>
" 初期設定関数を起動する
au FileType unite call s:unite_my_settings()
function! s:unite_my_settings()
  " Overwrite settings.
endfunction
" 様々なショートカット
call unite#set_substitute_pattern('file', '\$\w\+', '\=eval(submatch(0))', 200)
call unite#set_substitute_pattern('file', '^@@', '\=fnamemodify(expand("#"), ":p:h")."/"', 2)
call unite#set_substitute_pattern('file', '^@', '\=getcwd()."/*"', 1)
call unite#set_substitute_pattern('file', '^;r', '\=$VIMRUNTIME."/"')
call unite#set_substitute_pattern('file', '^\~', escape($HOME, '\'), -2)
call unite#set_substitute_pattern('file', '\\\@<! ', '\\ ', -20)
call unite#set_substitute_pattern('file', '\\ \@!', '/', -30)

" ========== programming lang setting ==========

"" for perl programming
autocmd FileType perl setlocal tabstop=4
autocmd FileType perl setlocal shiftwidth=4
autocmd FileType perl setlocal errorformat=%f:%l:%m
autocmd FileType perl setlocal autowrite
autocmd FileType t    setlocal filetype=perl
autocmd BufNewFile,BufRead *.psgi setlocal filetype=perl

"" for objective-c programming
"  *.m is not MATLAB file, but Objective-C
let g:filetype_m = 'objc'

"" for ruby programming
autocmd FileType ruby setlocal makeprg=ruby\ -c\ %
autocmd FileType ruby setlocal errorformat=%m\ in\ %f\ on\ line\ %l
autocmd BufNewFile,BufRead *.ru setlocal filetype=ruby

" Rubyのオムニ補完を設定(ft-ruby-omni)
let g:rubycomplete_buffer_loading = 1
let g:rubycomplete_classes_in_global = 1
let g:rubycomplete_rails = 1

"" for (X)HTML, XML, CSS coding
autocmd FileType html :compiler tidy
autocmd FileType html :setlocal makeprg=tidy\ -raw\ -quiet\ -errors\ --gnu-emacs\ yes\ \"%\"
autocmd BufNewFile,BufRead *.css setlocal syntax=css3
autocmd FileType html :set indentexpr=
autocmd FileType xhtml :set indentexpr=

"" for golang
autocmd BufRead,BufNewFile *.go setf go

"" for Markdown
autocmd BufNewFile,BufRead *.mkd      setfiletype mkd
autocmd BufNewFile,BufRead *.md       setfiletype mkd
autocmd BufNewFile,BufRead *.markdown setfiletype mkd
autocmd BufNewFile,BufRead *.mdown    setfiletype mkd
autocmd BufNewFile,BufRead *.mkdn     setfiletype mkd


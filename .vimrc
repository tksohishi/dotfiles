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
Bundle 'h1mesuke/unite-outline'
Bundle 'unite-colorscheme'
Bundle 'unite-font'
Bundle 'CommentAnyWay'
Bundle 'rails.vim'
Bundle 'surround.vim'
Bundle 'quickrun.vim'
Bundle 'matchit.zip'
Bundle 'ZenCoding.vim'
Bundle 'perlomni.vim'
Bundle 'rvm.vim'
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

" vim+iTerm2でマウスを使用できるようにする
set mouse=a
set guioptions+=a
set ttymouse=xterm2

" TODO
" vim+iTerm2でCommand-C, Command-Vを有効に

" ========== vim plugin setting ==========
" NOTE
" Using vundle for management
" The configurtion for that is on the top of this file

" unite.vim
" https://github.com/Shougo/unite.vim
" https://github.com/ujihisa/config/blob/master/_vimrc
nnoremap ;; :<C-u>Unite buffer<Cr>
nnoremap sb :<C-u>Unite buffer<Cr>
nnoremap se :<C-u>Unite file_rec<Cr>
nnoremap ss :<C-u>Unite file_rec<Cr>
nnoremap so :<C-u>Unite outline -auto-preview<Cr>
nnoremap sc :<C-u>Unite colorscheme -auto-preview<Cr>
nnoremap sf :<C-u>Unite file<Cr>
nnoremap sm :<C-u>Unite file_mru -winwidth=90<Cr>
" ウィンドウを横分割して開く
au FileType unite nnoremap <silent> <buffer> <expr> <C-j> unite#do_action('split')
au FileType unite inoremap <silent> <buffer> <expr> <C-j> unite#do_action('split')
" ウィンドウを縦分割して開く
au FileType unite nnoremap <silent> <buffer> <expr> <C-l> unite#do_action('vsplit')
au FileType unite inoremap <silent> <buffer> <expr> <C-l> unite#do_action('vsplit')
" ;;で挙動がおかしくなるのを防ぐ
" TODO 何故か閉じてくれないので要調査
au FileType unite nnoremap <silent> <buffer> ;; <Plug>(unite_exit)

let g:unite_enable_split_vertically = 1
let g:unite_winwidth=50
let g:unite_source_file_mru_time_format = '%D %H:%M '
let g:unite_source_file_rec_ignore_pattern = 'phpdoc\|\%(^\|/\)\.$\|\~$\|\.\%(o|exe|dll|bak|sw[po]\)$\|\%(^\|/\)\.\%(hg\|git\|bzr\|svn\)\%($\|/\)'

let g:unite_quick_match_table = {
      \'a' : 1, 's' : 2, 'd' : 3, 'f' : 4, 'g' : 5, 'h' : 6, 'j' : 7, 'k' : 8, 'l' : 9, ':' : 10,
      \'q' : 11, 'w' : 12, 'e' : 13, 'r' : 14, 't' : 15, 'y' : 16, 'u' : 17, 'i' : 18, 'o' : 19, 'p' : 20,
      \'1' : 21, '2' : 22, '3' : 23, '4' : 24, '5' : 25, '6' : 26, '7' : 27, '8' : 28, '9' : 29, '0' : 30,
      \}

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


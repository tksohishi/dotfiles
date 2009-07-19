" .vimrc edited by Takeshi Ohishi
" ChangeLog
" 2009/4/23 add the comments and setting
"  ref: http://relaxedcolumn.blog8.fc2.com/blog-entry-101.html
" ========== general setting ========== "
" Basic
set nocompatible
colorscheme evening
syntax enable

" Tab
" tabstopはTab文字を画面上で何文字分に展開するか
" shiftwidthはcindentやautoindent時に挿入されるインデントの幅
" softtabstopはTabキー押し下げ時の挿入される空白の量，0の場合はtabstopと同じ，BSにも影響する
set tabstop=4
set shiftwidth=4
set softtabstop=4
" tab => space
set expandtab
" ????
set smarttab

" Indent
set autoindent
set smartindent

" Input
set backspace=indent,eol,start " バックスペースでなんでも消せるように
set formatoptions+=m           " 整形オプション，マルチバイト系を追加
set imdisable                  " 日本語入力OFF(TODO:下の2つ要らないかも)
set iminsert=0                 " Insert mode時にIME OFF
set imsearch=0                 " Search時にIME OFF
set textwidth=99               " 1行99文字まで(80文字が理想)

" Search
set wrapscan   " 最後まで検索したら先頭へ戻る
set ignorecase " 大文字小文字無視
set smartcase  " 大文字ではじめたら大文字小文字無視しない
set incsearch  " インクリメンタルサーチ
set hlsearch   " 検索文字をハイライト

" File
filetype on         " 
filetype indent on  " 
filetype plugin on  " .vim/ftplugin/を有効に
set nobackup        " バックアップ取らない
set autoread        " 他で書き換えられたら自動で読み直す
set noswapfile      " スワップファイル作らない
set hidden          " 編集中でも他のファイルを開けるようにする

" Displaying
set showmatch         " 括弧の対応をハイライト
set showcmd           " 入力中のコマンドを表示
set number            " 行番号表示
set wrap              " 画面幅で折り返す
"set list              " 不可視文字表示
"set listchars=tab:>\  " 不可視文字の表示方法
set list
set listchars=tab:>.,trail:_,extends:>,precedes:< " 不可視文字の表示形式

set notitle           " タイトル書き換えない

" Moving
set scrolloff=5       " 行送り
" 同じ高さのインデントに移動する
nn <C-k> k:call search ("^". matchstr (getline (line (".")+ 1), '\(\s*\)') ."\\S", 'b')<CR>^
nn <C-j> :call search ("^". matchstr (getline (line (".")), '\(\s*\)') ."\\S")<CR>^

" Encoding
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,iso-2022-jp,euc-jp,cp932
set termencoding=utf-8

" 厳密な文字コード判別
" http://www.kawaz.jp/pukiwiki/?vim#content_1_7
" http://d.hatena.ne.jp/hazy-moon/20061229/1167407073

" free cursor
set whichwrap=b,s,h,l,<,>,[,]

" status line
" ref: http://www.e2esound.com/20080816/entry-id=303#
set laststatus=2
set statusline=%F%m%r%h%w\%=[TYPE=%Y]\[FORMAT=%{&ff}]\[ENC=%{&fileencoding}]\[LOW=%l/%L]\[COL=%v]

" Migemo
if has('migemo')
    set migemo
    set migemodict=/opt/local/share/migemo/utf-8/migemo-dict
endif

" short cut for Copy, Cut, Paste
" Copy  (Ctrl + c)
"vnoremap <c-c>"+y
" Cut   (Ctrl + x)
"vnoremap <c-x>"+x
" Paste (Ctrl + v)
"map <c-v>"+gP

" Copy and Paste
" Macの場合は普通にComamnd-C，Command-Vも使えたりする
if has('mac')
    map <silent> gy :call YankPB()<CR>
    function! YankPB()
        let tmp = tempname()
        call writefile(getline(a:firstline, a:lastline), tmp, 'b')
        silent exec ":!cat " . tmp . " | iconv -f utf-8 -t shift-jis | pbcopy"
    endfunction
endif
if has('win32')
    noremap gy "+y
    " ペーストがうまく動いてない
    noremap gp "+p
endif

" マウス操作を有効にする
" iTermのみ，Terminal.appでは無効
if has('mac')
    set mouse=a
    set ttymouse=xterm2
endif

" ========== vim plugin setting ==========

" minibufexpl.vim
let g:miniBufExplMapWindowNavVim = 1
let g:miniBufExplMapWindowNavArrows = 1
let g:miniBufExplMapCTabSwitchBufs = 1
let g:miniBufExplModSelTarget = 1

" qbuf.vim
let g:qb_hotkey = ";;"

" taglist.vim requires ctags
map P :TlistToggle<CR>

" tasklist.vim
map T :TaskList<CR>

" ========== programming lang setting ==========
"" for python programming
if has("autocmd")
    " Ctrl-nで入力補完,再度Ctrl-nで決定
    autocmd FileType python set complete+=k/Users/takeshi/.vim/plugin/pydiction/pydiction isk+=.,(
    " omni-completion Ctr-x Ctr-o
    " ref: http://blog.dispatched.ch/2009/05/24/vim-as-python-ide/
    autocmd FileType python set omnifunc=pythoncomplete#Complete
endif

"" for perl programming
" check perl code with :make
autocmd FileType perl set makeprg=perl\ -c\ %\ $*
autocmd FileType perl set errorformat=%f:%l:%m
autocmd FileType perl set autowrite
autocmd FileType t    set filetype=perl

"" for objective-c programming
"  *.m is not MATLAB file, but objectvie-c
let g:filetype_m = 'objc'
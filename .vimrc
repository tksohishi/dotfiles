" Encoding
set encoding=utf-8

" Tab and Indent
set tabstop=4
set shiftwidth=4
set expandtab
set smarttab
set autoindent

" Search
set wrapscan
set ignorecase
set smartcase
set incsearch
set hlsearch

" File
set nobackup
set nowritebackup
set noswapfile
set autoread
set hidden
set fileformat=unix
set fileformats=unix,dos,mac

" Display
set number
set ruler
set showcmd
set showmatch
set nowrap
set list
set listchars=tab:>.,trail:_,extends:>,precedes:<
set scrolloff=5
set laststatus=2

" Input
set backspace=indent,eol,start
set whichwrap=b,s,h,l,<,>,[,]
set mouse=a
set vb t_vb=

" Completion
set wildmode=longest,list,full
set completeopt=menuone

" History
set history=100

" Status Line
let &statusline = ''
let &statusline .= '%3n '
let &statusline .= '%<%f '
let &statusline .= '%m%r%h%w'
let &statusline .= '%{"[" . (&fileencoding != "" ? &fileencoding : &encoding) . "][" . &fileformat . "][" . &filetype . "]"}'
let &statusline .= '%='
let &statusline .= '%l/%L,%c%V'
let &statusline .= '%4P'

" Syntax and Filetype
syntax enable
filetype plugin indent on

" Move cursor by display line
noremap j gj
noremap k gk
noremap gj j
noremap gk k

" Center search results
nnoremap n nzz
nnoremap N Nzz
nnoremap * *zz
nnoremap # #zz
nnoremap g* g*zz
nnoremap g# g#zz

" Clear search highlight
nnoremap <Esc><Esc> :<C-u>set nohlsearch<CR>
nnoremap / :<C-u>set hlsearch<CR>/
nnoremap ? :<C-u>set hlsearch<CR>?
nnoremap * :<C-u>set hlsearch<CR>*
nnoremap # :<C-u>set hlsearch<CR>#

" Leader
let mapleader=","

" Quick save
nnoremap <Leader>w :<C-u>update<CR>

" Quick vimrc edit/reload
nnoremap <Leader>.  :<C-u>edit $MYVIMRC<CR>
nnoremap <Leader>s. :<C-u>source $MYVIMRC<CR>

set secure

" vim: set ts=4 sw=4 et:

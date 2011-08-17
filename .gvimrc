" .gvimrc created by Takeshi Ohishi "

"" The setting for MacVim
if has('gui_macvim')
"    set showtabline=2     " displaying tab bar(0: Never 1: over two 2: Always)
    set transparency=5     " transparency 0-100
    set columns=180        " Window size(width)
    set lines=50           " Window size(height)
    colorscheme molokai    " other candidates: murphy,slate,torte,railscasts,solarized,koehler
    set guifont=Monaco:h13 " Font Monaco 13pt
    set cursorline         " カーソル行の強調
    set background=dark    " For solarized
endif

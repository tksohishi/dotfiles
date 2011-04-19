" .gvimrc created by Takeshi Ohishi "

"" The setting for MacVim
if has('gui_macvim')
"    set showtabline=2     " displaying tab bar(0: Never 1: over two 2: Always)
    set transparency=15    " transparency 0-100
    set columns=180        " Window size(width)
    set lines=50           " Window size(height)
    colorscheme koehler    " other candidates: murphy,slate,torte,railscasts,solarized
    set guifont=Monaco:h13 " Font Monaco 13pt
    set cursorline         " カーソル行の強調
    set background=dark    " For solarized

    " For MobaSiF
    " set noexpandtab      " Not using MobaSiF anymore, I hope...
endif

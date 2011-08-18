" .gvimrc created by Takeshi Ohishi "

"" The setting for MacVim
if has('gui_macvim')
    set transparency=10      " transparency 0-100
    set columns=180          " Window size(width)
    set lines=50             " Window size(height)
    colorscheme molokai      " other candidates: murphy,slate,torte,railscasts,solarized,koehler
    set guifont=Monaco:h13   " Font Monaco 13pt
    set cursorline           " カーソル行の強調
    set background=dark      " For solarized
    let g:molokai_original=1 " For molokai
endif

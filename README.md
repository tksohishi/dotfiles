# dotfiles

## How to setup

### clone repository in home directory

```shell
git clone git@github.com:tksohishi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
git submodule update --init
```

### run bootstrap.sh

```shell
./bootstrap.sh
```

  input 'y' to have done

### Set up vim

```shell
mkdir -p ~/.vim/bundle
cd ~/.vim/bundle
git clone https://github.com/Shougo/neobundle.vim.git
vim
# Run Neobundle/Install
```
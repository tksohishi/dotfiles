# dotfiles

macOS machine setup: shell configs, editor settings, git config, tool preferences, and all applications managed via Homebrew and the Mac App Store.

## Setup

```shell
git clone git@github.com:tksohishi/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

This will:

1. Install Homebrew (if not already installed)
2. Install all CLI tools, GUI apps, and App Store apps from the `Brewfile`
3. Symlink dotfiles to `$HOME`

## Adding or removing packages

Edit the `Brewfile` and run:

```shell
brew bundle
```

To check for installed packages not listed in the Brewfile:

```shell
brew bundle cleanup
```

#!/bin/bash

echo Bootstrap for creating my own environment like dotfiles and zsh

if test -f list; then
    echo start!
else
    echo make list!
    ls -A > list
    $EDITOR $(pwd)/list
fi

list=`cat list`
y=yes
n=no
echo make the following files links
echo -------------------------------
echo "$list"
echo -------------------------------
echo OK? choose one!
select Answer in yes Ctrl-C:cancel
do
    break;
done

for i in $list
do
    if test -L ../"$i"; then
        echo ../"$i" is just a symbolic link, so deleted it
        rm ../"$i"
        elif test -f ../"$i"; then
        echo ../"$i" is file, so renamed it
        mv ../"$i" ../"$i".org
    fi
    ln -s $(pwd)/"$i" ../"$i"
    echo $i is created
done

echo complete link making

echo Prerequisites: install starship, zoxide, and mise via homebrew
echo "  brew install starship zoxide mise"

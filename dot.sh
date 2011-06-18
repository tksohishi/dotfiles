#!/bin/bash
# NOTICE: this shell script make link on ../ directry

echo dot file link maker

if test -f filelist; then
    echo start!
else
    echo make filelist!
    ls -A > filelist
    $EDITOR $(pwd)/filelist
fi

filelist=`cat filelist`
y=yes
n=no
echo make the following files links
echo -------------------------------
echo "$filelist"
echo -------------------------------
echo OK? choose one!
select Answer in yes Ctrl-C:cancel
do
    break;
done

for i in $filelist
do
    if test -L ../"$i"; then
        echo ../"$i" is just a symbolic link, so deleted it
        rm ../"$i"
        elif test -f ../"$i"; then
        echo ../"$i" is file, so renamed it
        mv ../"$i" ../"$i".org
    fi
    ln -s $(pwd)/"$i" ../"$i"
done

#ls -ltra ../
echo complete link making

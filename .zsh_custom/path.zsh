# local binary
[ -d $HOME/local/bin ] && export PATH=$HOME/local/bin:$PATH

# node.js and npm
[ -f /usr/local/share/npm/bin ] && export PATH=$PATH:/usr/local/share/npm/bin
[ -d /usr/local/lib/node ] && export NODE_PATH=/usr/local/lib/node_modules


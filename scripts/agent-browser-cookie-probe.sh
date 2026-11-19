#!/bin/zsh
# Checks that agent-browser's Chrome still stores a project profile's cookies under the v10 key. bin/agent-browser
# disables KeychainKeyProviderUserDataDirProtection, which otherwise re-encrypts them as v11 and drops them on the next
# change of key. Prints the prefix; exits 0 on v10, 1 on anything else (the flag stopped working), 2 if no cookie
# was stored.
set -u
root=${0:A:h:h}
dir=$root/tmp/agent-browser-cookie-probe
trash "$dir" 2>/dev/null
mkdir -p "$dir" && cd "$dir" || exit 2
print -r -- '{"session":"cookie-probe","profile":"./profile"}' > agent-browser.json
# the browser must be up before cookies set: a set that launches it is not stored
agent-browser -q open https://example.com >/dev/null
agent-browser -q cookies set probe 1 --url https://example.com --expires $(( $(date +%s) + 86400 )) >/dev/null
agent-browser -q close >/dev/null
sleep 2
prefix=$(sqlite3 -readonly "file:profile/Default/Network/Cookies?immutable=1" "select substr(encrypted_value,1,3) from cookies where name='probe';" 2>/dev/null)
print -r -- "${prefix:-none}"
[ -z "$prefix" ] && exit 2
[ "$prefix" = v10 ]

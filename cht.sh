#!/usr/bin/env bash

languages=`echo "lua typescript rust" | tr ' ' '\n'`
utils=`echo "nvim xargs mv sed awk" | tr ' ' '\n'`

# selected=`echo "$languages $utils" | tr ' ' '\n' | fzf`
selected=`curl -s cheat.sh/:list | fzf`

read -p "query: " query

# if printf $languages | grep -qs $selected; then
  curl cht.sh/$selected/`echo $query | tr ' ' '+'`
# else
#   curl cht.sh/$selected~$query
# fi

while true; do
    sleep 1
done

#!/bin/sh

EXPR=$@

if [ -z "$EXPR" ]; then
    EXPR="he goes and she goes"
fi

IMAGE_FILE=`mktemp`
make
if ./bin/parse-english -e "$EXPR" -x; then
    ./bin/parse-english -e "$EXPR" -d 2> /dev/null | dot -Tpng > $IMAGE_FILE; xdg-open $IMAGE_FILE
fi

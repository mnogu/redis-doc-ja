#!/bin/bash

if [[ ! -d translated/source/topics ]]; then
    mkdir translated/source/topics
fi

cd redis-doc
find topics -name "*.md" -print0 | while read -r -d '' md;
do
    CONVERTED="../translated/source/${md%.*}.rst"
    echo -n "Translating $md ... "
    if [ "$md" -nt "$CONVERTED" ]; then
        pandoc "$md" -o "$CONVERTED"
        touch -r "$CONVERTED" "$md"
        echo "done."
    else
        echo "skipped."
    fi
done

find topics \( -name "*.jpg" -or -name "*.png" -or -name "*.gif" \) -print0 | while read -r -d '' img;
do
    COPIED="../translated/source/$img"
    echo -n "Copying $img ... "
    if [ "$img" -nt "$COPIED" ]; then
        cp -a "$img" "$COPIED"
        echo "done."
    else
        echo "skipped."
    fi
done


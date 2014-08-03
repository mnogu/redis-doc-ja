#!/bin/sh

dir=$1

cd $dir
for file in `ls *.po`; do
  echo $file
  msgfmt $file -o "${file%%.po}".mo
done

#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1

sjasmplus src/main.asm --raw=c0man.rom
status=$?
echo

if [ $status -eq 0 ]
then
    echo "Build OK: c0man.rom"
else
    echo "BUILD FAILED"
    exit 1
fi

echo

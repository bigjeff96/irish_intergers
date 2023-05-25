#!/usr/bin/bash
ODIN="~/Dropbox/Projects/odin/odin-ubuntu-amd64-dev-2023-05/./odin"
set -e
echo BUILD:
time odin build . -debug -use-separate-modules
echo OUTPUT:
./irish_integers.bin

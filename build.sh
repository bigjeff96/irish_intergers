#!/usr/bin/bash

set -e
echo BUILD:
time odin build . -o:none -debug -use-separate-modules -ignore-warnings
echo OUTPUT:
./irish_integers.bin

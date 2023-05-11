#!/usr/bin/bash

set -e
echo BUILD:
time odin build . -debug -use-separate-modules 
echo OUTPUT:
./irish_integers.bin 

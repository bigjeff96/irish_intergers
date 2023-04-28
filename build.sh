#!/usr/bin/bash

set -e
echo BUILD:
time odin build . -o:none -debug -use-separate-modules
echo OUTPUT:
./lucky_numbers.bin 

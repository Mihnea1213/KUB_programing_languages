#!/bin/bash

#Curatenie
echo "Cleaning up..."
rm -f lex.yy.c limbaj.tab.c limbaj.tab.h compilator

#Generam codul C cu Bison
echo "Compiling Bison..."
bison -d limbaj.y

#Generam codul C cu Flex
echo "Compiling Flex..."
flex limbaj.l

#Compilam totul in executabil
echo "Compiling C++..."
g++ limbaj.tab.c lex.yy.c -o compilator

#Rulam doar daca s-a creat executabilul
if [ -f "./compilator" ]; then
    echo "Compilation finished. Running..."
    echo "-------------------------------"
    ./compilator
else
    echo "ERROR: Compilation failed!"
fi
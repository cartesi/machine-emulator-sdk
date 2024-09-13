#!/bin/bash

echo $1
echo rmd160 $(openssl dgst -rmd160 $1 | sed 's/^.*=//') \\
echo sha256 $(openssl dgst -sha256 $1 | sed 's/^.*=//') \\
stat -f "size   %z \\" $1

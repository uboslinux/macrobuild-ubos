#!/bin/bash
#
# Simple script to emit the dependencies of a package by invoking PKGBUILD
# arg1: PKGBUILD file

. $1
echo ${depends[@]}
echo ${makedepends[@]}

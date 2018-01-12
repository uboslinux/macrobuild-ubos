#!/bin/bash
#
# Simple script to emit the dependencies of a package by invoking PKGBUILD
# arg1: PKGBUILD file
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

. $1
echo ${depends[@]}
echo ${makedepends[@]}

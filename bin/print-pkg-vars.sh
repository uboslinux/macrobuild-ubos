#!/bin/bash
#
# Simple script to print some key variables in a PKGBUILD
# arg1: PKGBUILD file
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

. $1
echo arch: ${arch}
echo depends: ${depends[@]}
echo makedepends: ${makedepends[@]}
echo pkgname: ${pkgname}
echo pkgrel: ${pkgrel}
echo pkgver: ${pkgver}

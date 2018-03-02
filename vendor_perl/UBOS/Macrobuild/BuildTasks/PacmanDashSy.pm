#!/usr/bin/perl
#
# Download fresh package databases. Simply invokes 'pacman -Sy'.
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PacmanDashSy;

use base qw( Macrobuild::Task );
use fields;

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $ret = 0;

    if( UBOS::Utils::myexec( 'sudo pacman -Sy' )) {
        return FAIL();
    }

    return SUCCESS();
}

1;


#!/usr/bin/perl
#
# Upgrade the current system. Simply invokes 'ubos-admin update'.
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UpgradeSystem;

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

    if( UBOS::Utils::myexec( 'sudo ubos-admin update --noreboot --nokeyrefresh' )) {
        return FAIL();
    }

    return SUCCESS();
}

1;


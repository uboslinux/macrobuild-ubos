#
# Config file for upstream sources obtained by download
#

use strict;
use warnings;

package UBOS::Macrobuild::DownloadUsConfig;

use base qw( UBOS::Macrobuild::AbstractUsConfig );
use fields;

use UBOS::Logging;
use UBOS::Utils;

##
# Constructor same as super class'

##
# Get the type
sub type {
    my $self = shift;

    return 'download';
}

1;

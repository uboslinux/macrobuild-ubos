#
# Execute pacsane
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PacsaneRepository;

use base qw( Macrobuild::Task );
use fields qw( dbfile );

use Macrobuild::Task;
use UBOS::Logging;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $dbfile = $run->getProperty( 'dbfile' );

    my $ret = 0;
    unless( -e $dbfile ) {
        # a db that does not exist on this arch
        trace( 'PacsaneRepository: skipping db, it does not exist:', $dbfile );
        return DONE_NOTHING;
    }
    if( UBOS::Utils::myexec( "pacsane '$dbfile'" )) {
        return FAIL;
    } else {
        return SUCCESS;
    }
}

1;


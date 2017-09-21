#
# Unstage removed packages from the stage directory
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Unstage;

use base qw( Macrobuild::Task );
use fields qw( stagedir );

use Macrobuild::Task;
use UBOS::Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    my $unstaged = {};
    if( exists( $in->{'removed-packages'} )) {

        my $removedPackages = $in->{'removed-packages'};

        my $destDir = $self->getProperty( 'stagedir' );

        UBOS::Macrobuild::Utils::ensureDirectories( $destDir );

        if( %$removedPackages ) {
            foreach my $uXConfigName ( sort keys %$removedPackages ) {
                my $uXConfigData = $removedPackages->{$uXConfigName};

                foreach my $packageName ( sort keys %$uXConfigData ) {
                    $unstaged->{$packageName} = [];

                    foreach my $fileName ( @{$uXConfigData->{$packageName}} ) {

                        my $localFileName = $fileName;
                        $localFileName =~ s!.*/!!;

                        UBOS::Utils::myexec( "rm '$destDir/$localFileName'" );
                        if( -e "$destDir/$localFileName.sig" ) {
                            UBOS::Utils::myexec( "rm '$destDir/$localFileName'" );
                        }

                        push @{$unstaged->{$packageName}}, "$destDir/$localFileName";
                    }
                    trace( "Unstaged:", $packageName, @{$unstaged->{$packageName}} );
                }
            }
        }
    }

    $run->setOutput( {
            'unstaged-packages' => $unstaged
    } );

    if( %$unstaged ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;


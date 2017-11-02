#
# Determine into which package dbs the provided packages go.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PointPatchDispatch;

use base qw( Macrobuild::Task );
use fields qw( upconfigs usconfigs packageFile );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $packageFiles = $self->getProperty( 'packageFile' );
    if( !$packageFiles ) {
        $packageFiles = [];
    } elsif( !ref( $packageFiles )) {
        $packageFiles = [ $packageFiles ];
    }
    my $upconfigs = $self->getProperty( 'upconfigs' );
    my $usconfigs = $self->getProperty( 'usconfigs' );

    my $dispatched  = {};
    my $found       = {};
    my $ret;
    if( @$packageFiles ) {
        $ret = SUCCESS;

        foreach my $packageFile ( @$packageFiles ) {
            my $shortPackageFile = $packageFile;
            $shortPackageFile =~ s!.*/!!;

            my $parsedPackageFile = UBOS::Macrobuild::PackageUtils::parsePackageFileName( $shortPackageFile );
            my $packageName       = $parsedPackageFile->{'name'};

            $found->{$packageName} = 0;
            OUTER1: foreach my $db ( sort keys %$upconfigs ) {
                my $configs = $upconfigs->{$db}->configs( $self );
                foreach my $upConfigName ( sort keys %$configs ) {
                    my $upConfig = $configs->{$upConfigName};

                    if( $upConfig->containsPackage( $packageName )) {
                        $dispatched->{$upConfigName}->{$packageName} = $packageFile;
                        $found->{$packageName} = 1;
                        last OUTER1;
                    }
                }
            }
            unless( $found->{$packageName} ) {
                OUTER2: foreach my $db ( sort keys %$usconfigs ) {
                    my $configs = $usconfigs->{$db}->configs( $self );
                    foreach my $usConfigName ( sort keys %$configs ) {
                        my $usConfig = $configs->{$usConfigName};

                        if( $usConfig->containsPackage( $packageName )) {
                            $dispatched->{$usConfigName}->{$packageName} = $packageFile;
                            $found->{$packageName} = 1;
                            last OUTER2;
                        }
                    }
                }
            }
        }
        foreach my $packageName ( keys %$found ) {
            unless( $found->{$packageName} ) {
                error( 'Could not find package in upconfigs or usconfigs:', $packageName );
                $ret = FAIL;
            }
        }
    } else {
        $ret = DONE_NOTHING;
    }

    $run->setOutput( {
            'new-packages' => $dispatched,
            'old-packages' => {}
    } );

    return $ret;
}

1;


#
# Check that there are no overlaps in any of the UpConfigs and UsConfigs
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;

use base qw( Macrobuild::Task );
use fields qw( repoUpConfigs repoUsConfigs );

use Macrobuild::Task;
use Macrobuild::Utils;
use UBOS::Logging;

##
# @Overrides
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $errors = 0;

    my $repoUpConfigs = $run->getProperty( 'repoUpConfigs' );
    my $repoUsConfigs = $run->getProperty( 'repoUsConfigs' );

    trace( 'CheckPossibleOverlaps:', keys %$repoUpConfigs, keys %$repoUsConfigs );

    my $all = {};
    foreach my $name ( keys %$repoUpConfigs ) {
        my $upConfigs = $repoUpConfigs->{$name};

        my $configs = $upConfigs->configs( $run );
        foreach my $configName ( keys %$configs ) {
            my $upConfig      = $configs->{$configName};
            my $overlapBucket = $upConfig->overlapBucket();
            my $packages      = $upConfig->packages();

            foreach my $package ( keys %$packages ) {
                if( exists( $all->{$overlapBucket}->{$package} )) {
                    my $already = $all->{$overlapBucket}->{$package};
                    error( 'Package', $package, ', overlap bucket', $overlapBucket, 'exists both in', $already, 'and', $configName, ':', $package );
                    ++$errors;
                } else {
                    $all->{$overlapBucket}->{$package} = $configName;
                }
            }
        }
    }
    foreach my $name ( keys %$repoUsConfigs ) {
        my $usConfigs = $repoUsConfigs->{$name};

        my $configs = $usConfigs->configs( $run );
        foreach my $configName ( keys %$configs ) {
            my $upConfig      = $configs->{$configName};
            my $overlapBucket = $upConfig->overlapBucket();
            my $packages      = $upConfig->packages();

            foreach my $package ( keys %$packages ) {
                if( exists( $all->{$overlapBucket}->{$package} )) {
                    my $already = $all->{$overlapBucket}->{$package};
                    error( 'Package', $package, ', overlap bucket', $overlapBucket, 'exists both in', $already, 'and', $configName, ':', $package );
                    ++$errors;
                } else {
                    $all->{$overlapBucket}->{$package} = $configName;
                }
            }
        }
    }

    if( $errors ) {
        return FAIL;
    } else {
        return SUCCESS;
    }
}



1;


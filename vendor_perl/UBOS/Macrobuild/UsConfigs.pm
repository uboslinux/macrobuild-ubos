#
# Applicable UsConfigs. This is only resolved after construction.
#

use strict;
use warnings;

package UBOS::Macrobuild::UsConfigs;

use fields qw( dir configsCache localSourcesDir );

use UBOS::Logging;
use UBOS::Macrobuild::DownloadUsConfig;
use UBOS::Macrobuild::GitUsConfig;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;

##
# Constructor.
# $dir: the directory in which to read all files
# $localSourcesDir: path that may override the url field in UsConfig JSONs
sub allIn {
    my $self            = shift;
    my $dir             = shift;
    my $localSourcesDir = shift;

    unless( ref( $dir )) {
        $self = fields::new( $self );
    }

    $self->{dir}             = $dir;
    $self->{configsCache}    = undef;
    $self->{localSourcesDir} = $localSourcesDir;

    return $self;
}

##
# Return a hash of UsConfigs, keyed by their short source name
# $task: the Task context to use
# return: hash of short source name to UsConfig
sub configs {
    my $self = shift;
    my $task = shift;

    my $arch = $task->getValue( 'arch' );

    my $localSourcesDir;
    if( defined( $self->{localSourcesDir} )) {
        $localSourcesDir = $task->replaceVariables( $self->{localSourcesDir} );
    }

    my $ret = $self->{configsCache};
    unless( $ret ) {
        my $realDir = $task->replaceVariables( $self->{dir} );

        unless( -d $realDir ) {
            trace( "Upstream sources config dir not found:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        my @files = <$realDir/*.json>;
        unless( @files ) {
            trace( "No config files found in upstream sources config dir:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        $ret = {};
        $self->{configsCache} = $ret;

        foreach my $file ( @files ) {
            trace( "Now reading upstream sources config file", $file );
            my $shortSourceName = $file;
            $shortSourceName =~ s!.*/!!;
            $shortSourceName =~ s!\.json$!!;

            my $usConfigJson = UBOS::Utils::readJsonFromFile( $file );
            my $archs        = $usConfigJson->{archs};
            if( exists( $usConfigJson->{archs} ) && !UBOS::Macrobuild::Utils::useForThisArch( $arch, $usConfigJson->{archs} )) {
                trace( 'Skipping', $file, 'for arch', $arch );
                next;
            }

            if( ! $usConfigJson->{type} ) {
                warning( "No type given in $file, skipping." );
                next;
            }
            my $packages       = $usConfigJson->{packages};
            my $removePackages = $usConfigJson->{'remove-packages'};
            my $webapptests    = $usConfigJson->{webapptests};

            UBOS::Macrobuild::Utils::removeItemsNotForThisArch( $packages,    $arch );
            UBOS::Macrobuild::Utils::removeItemsNotForThisArch( $webapptests, $arch );

            if( $usConfigJson->{type} eq 'git' ) {
                my $branch = $task->replaceVariables( $usConfigJson->{branch} );

                $ret->{$shortSourceName} = new UBOS::Macrobuild::GitUsConfig(
                        $shortSourceName,
                        $usConfigJson,
                        $file,
                        $localSourcesDir,
                        $packages,
                        $removePackages,
                        $webapptests,
                        $branch );

            } elsif( $usConfigJson->{type} eq 'download' ) {
                $ret->{$shortSourceName} = new UBOS::Macrobuild::DownloadUsConfig(
                        $shortSourceName,
                        $usConfigJson,
                        $file,
                        $localSourcesDir,
                        $packages,
                        $removePackages,
                        $webapptests );
            } else {
                warning( "Unknown type", $usConfigJson->{type}, "given in $file, skipping." );
                next;
            }
        }
    }
    return $ret;
}

1;

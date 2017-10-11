#
# Applicable UpConfigs. This is only resolved after construction.
#

use strict;
use warnings;

package UBOS::Macrobuild::UpConfigs;

use fields qw( dir configsCache );

use UBOS::Logging;
use UBOS::Macrobuild::UpConfig;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;

##
# Constructor.
# $dir: the directory in which to read all files
sub allIn {
    my $self = shift;
    my $dir  = shift;

    unless( ref( $dir )) {
        $self = fields::new( $self );
    }

    $self->{dir}          = $dir;
    $self->{configsCache} = undef;

    return $self;
}

##
# Return a hash of UpConfigs, keyed by their short repository name
# $task: the Task context to use
# return: hash of short repo name to UpConfig, or undef if could not be parsed
sub configs {
    my $self = shift;
    my $task = shift;

    my $arch = $task->getValue( 'arch' );

    my $ret = $self->{configsCache};
    unless( $ret ) {
        my $realDir = $self->{dir};

        unless( -d $realDir ) {
            trace( "Upstream packages config dir not found:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        my @files = <$realDir/*.json>;
        unless( @files ) {
            trace( "No config files found in upstream packages config dir:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        $ret = {};
        $self->{configsCache} = $ret;

        foreach my $file ( @files ) {
            trace( "Now reading upstream packages config file", $file );
            my $shortRepoName = $file;
            $shortRepoName =~ s!.*/!!;
            $shortRepoName =~ s!\.json$!!;

            my $upConfigJson = UBOS::Utils::readJsonFromFile( $file );
            unless( $upConfigJson ) {
                next;
            }
            my $archs = $upConfigJson->{archs};

            if( exists( $upConfigJson->{archs} ) && !UBOS::Macrobuild::Utils::useForThisArch( $arch, $upConfigJson->{archs} )) {
                trace( 'Skipping', $file, 'for arch', $arch );
                next;
            }

            my $upstreamDir = $upConfigJson->{upstreamDir};
            unless( $upstreamDir ) {
                error( 'Field upstreamDir not set in', $file );
                next;
            }

            my $packages  = $upConfigJson->{packages};
            UBOS::Macrobuild::Utils::removeItemsNotForThisArch( $packages, $arch );

            my $directory = $task->replaceVariables(
                    $upstreamDir,
                    { 'shortdb' => $shortRepoName } );

            unless( !defined( $directory ) || ( $directory =~ m!^/! && -d $directory ) || $directory =~ m!^https?://! ) {
                warning( "No or invalid directory given in $file, skipping: ", $directory );
                next;
            }
            my $lastModified   = (stat( $file ))[9];
            my $removePackages = $upConfigJson->{'remove-packages'};

            $ret->{$shortRepoName} =
                    UBOS::Macrobuild::UpConfig->new( $shortRepoName, $upConfigJson, $lastModified, $directory, $packages, $removePackages );
        }
    }
    return $ret;
}

1;

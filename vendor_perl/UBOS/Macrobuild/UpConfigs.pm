# 
# Applicable UpConfigs. This is only resolved after construction.
#

use strict;
use warnings;

package UBOS::Macrobuild::UpConfigs;

use fields qw( dir settingsConfigsMap );

use UBOS::Logging;
use UBOS::Macrobuild::UpConfig;
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

    $self->{dir}                = $dir;
    $self->{settingsConfigsMap} = {};

    return $self;
}

##
# Return a hash of UpConfigs, keyed by their short repository name
# $settings: the settings to use
sub configs {
    my $self     = shift;
    my $settings = shift;

    my $ret = $self->{settingsConfigsMap}->{$settings->getName};
    unless( $ret ) {
        my $realDir = $settings->replaceVariables( $self->{dir} );

        my @files = <$realDir/*.json>;
        unless( @files ) {
            debug( "No config files found in upstream packages config dir:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        $ret = {};
        $self->{settingsConfigsMap}->{$settings->getName} = $ret;

        foreach my $file ( @files ) {
            debug( "Now reading upstream packages config file", $file );
            my $shortRepoName = $file;
            $shortRepoName =~ s!.*/!!;
            $shortRepoName =~ s!\.json$!!;

            my $upConfigJson = UBOS::Utils::readJsonFromFile( $file );
            my $directory    = $upConfigJson->{directory};
            my $packages     = $upConfigJson->{packages};

            unless( defined( $directory )) {
                warning( "No directory given in $file, skipping." );
                next;
            }
            $directory = $settings->replaceVariables( $directory );

            unless( !defined( $directory ) || ( $directory =~ m!^/! && -d $directory ) || $directory =~ m!^https?://! ) {
                warning( "No or invalid directory given in $file, skipping: ", $directory );
                next;
            }
            my $lastModified = (stat( $file ))[9];
            $ret->{$shortRepoName} = new UBOS::Macrobuild::UpConfig( $shortRepoName, $lastModified, $directory, $packages );
        }
    }
    return $ret;
}

##
# Check that there is no overlap in the the ups
# $ups: hash of name to UpConfig
# $settings: settings object
# will exit with fatal if there is overlap
sub checkNoOverlap {
    my $ups      = shift;
    my $settings = shift;

    my $all = {};
    foreach my $name ( keys %$ups ) {
        my $upConfigs = $ups->{$name};

        my $configs = $upConfigs->configs( $settings );
        foreach my $configName ( keys %$configs ) {
            my $upConfig = $configs->{$configName};

            $all->{"$name/$configName"} = $upConfig;
        }
    }
    my @names = sort keys %$all;
    for( my $i=0 ; $i<@names-1 ; ++$i ) {
        my $iUp  = $all->{$names[$i]};
        my $iDir = $iUp->directory();
        
        my @iPackages = keys %{$iUp->packages()};

        for( my $j= $i+1 ; $j<@names ; ++$j ) {
            my $jUp  = $all->{$names[$j]};
            my $jDir = $jUp->directory();

            if( $iDir ne $jDir ) {
                next;
            }
            my @jPackages = keys %{$jUp->packages()};

            foreach my $iPackage ( @iPackages ) {
                foreach my $jPackage ( @jPackages ) {
                    if( $iPackage eq $jPackage ) {
                        fatal( 'Package overlap:', $iPackage, 'is listed in UpConfigs', $names[$i], 'and', $names[$j] );
                    }
                }
            }
        }
    }
}

1;

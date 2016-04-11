# 
# Applicable UsConfigs. This is only resolved after construction.
#

use strict;
use warnings;

package UBOS::Macrobuild::UsConfigs;

use fields qw( dir settingsConfigsMap localSourcesDir );

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

    $self->{dir}                = $dir;
    $self->{settingsConfigsMap} = {};
    $self->{localSourcesDir}    = $localSourcesDir;

    return $self;
}

##
# Return a hash of UsConfigs, keyed by their short source name
# $settings: the settings to use
sub configs {
    my $self     = shift;
    my $settings = shift;

    my $arch = $settings->getVariable( 'arch' );
    unless( $arch ) {
        error( 'Variable not set: arch' );
        return undef;
    }
    
    my $localSourcesDir;
    if( defined( $self->{localSourcesDir} )) {
        $localSourcesDir = $settings->replaceVariables( $self->{localSourcesDir} );
    }

    my $ret = $self->{settingsConfigsMap}->{$settings->getName};
    unless( $ret ) {
        my $realDir = $settings->replaceVariables( $self->{dir} );

        unless( -d $realDir ) {
            debug( "Upstream sources config dir not found:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        my @files = <$realDir/*.json>;
        unless( @files ) {
            debug( "No config files found in upstream sources config dir:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        $ret = {};
        $self->{settingsConfigsMap}->{$settings->getName} = $ret;

        foreach my $file ( @files ) {
            debug( "Now reading upstream sources config file", $file );
            my $shortSourceName = $file;
            $shortSourceName =~ s!.*/!!;
            $shortSourceName =~ s!\.json$!!;

            my $usConfigJson = UBOS::Utils::readJsonFromFile( $file );
            my $archs        = $usConfigJson->{archs};

            if( exists( $usConfigJson->{archs} ) && !UBOS::Macrobuild::Utils::useForThisArch( $arch, $usConfigJson->{archs} )) {
                debug( 'Skipping', $file, 'for arch', $arch );
                next;
            }

            if( ! $usConfigJson->{type} ) {
                warning( "No type given in $file, skipping." );
                next;
            } elsif( $usConfigJson->{type} eq 'git' ) {
                $ret->{$shortSourceName} = new UBOS::Macrobuild::GitUsConfig(
                        $shortSourceName,
                        $usConfigJson,
                        $file,
                        $localSourcesDir );

            } elsif( $usConfigJson->{type} eq 'download' ) {
                $ret->{$shortSourceName} = new UBOS::Macrobuild::DownloadUsConfig(
                        $shortSourceName,
                        $usConfigJson,
                        $file,
                        $localSourcesDir );
            } else {
                warning( "Unknown type", $usConfigJson->{type}, "given in $file, skipping." );
                next;
            }
        }
    }
    return $ret;
}

##
# Check that there is no overlap in the the uSs
# $uss: hash of name to UsConfig
# $settings: settings object
# will exit with fatal if there is overlap
sub checkNoOverlap {
    my $uss      = shift;
    my $settings = shift;

    my $all = {};
    foreach my $name ( keys %$uss ) {
        my $usConfigs = $uss->{$name};

        my $configs = $usConfigs->configs( $settings );
        foreach my $configName ( keys %$configs ) {
            my $usConfig      = $configs->{$configName};
            my $overlapBucket = $usConfig->overlapBucket();

            $all->{$overlapBucket}->{"$name/$configName"} = $usConfig;
        }
    }

    foreach my $overlapBucket ( sort keys %$all ) {
        my $bucketContent = $all->{$overlapBucket};

        my @names = sort keys %$bucketContent;
        for( my $i=0 ; $i<@names-1 ; ++$i ) {
            my $iUs = $bucketContent->{$names[$i]};
            
            my @iPackages = keys %{$iUs->packages()};

            for( my $j= $i+1 ; $j<@names ; ++$j ) {
                my $jUs = $bucketContent->{$names[$j]};

                if( ref( $iUs ) ne ref( $jUs )) {
                    # e.g. Github vs Download
                    next;
                }
                if( $iUs->url() ne $jUs->url() ) {
                    next;
                }

                my @jPackages = keys %{$jUs->packages()};

                foreach my $iPackage ( @iPackages ) {
                    foreach my $jPackage ( @jPackages ) {
                        if( $iPackage eq $jPackage ) {
                            fatal( 'Package overlap in overlap bucket', $overlapBucket, ':', $iPackage, 'is listed in UsConfigs', $names[$i], 'and', $names[$j] );
                        }
                    }
                }
            }
        }
    }
}

1;

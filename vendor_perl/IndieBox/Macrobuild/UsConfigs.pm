# 
# Applicable UsConfigs. This is only resolved after construction.
#

use strict;
use warnings;

package IndieBox::Macrobuild::UsConfigs;

use fields qw( dir settingsConfigsMap );

use IndieBox::Macrobuild::DownloadUsConfig;
use IndieBox::Macrobuild::GitUsConfig;
use IndieBox::Utils;
use Macrobuild::Logging;

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
# Return a hash of UsConfigs, keyed by their short source name
# $settings: the settings to use
sub configs {
    my $self     = shift;
    my $settings = shift;

    my $ret = $self->{settingsConfigsMap}->{$settings->getName};
    unless( $ret ) {
        my $realDir = $settings->replaceVariables( $self->{dir} );

        my @files = <$realDir/*.json>;
        unless( @files ) {
            Macrobuild::Logging::debug( "No config files found in upstream sources config dir:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        $ret = {};
        $self->{settingsConfigsMap}->{$settings->getName} = $ret;

        CONFIGFILES:
        foreach my $file ( @files ) {
            Macrobuild::Logging::info( "Now reading upstream sources config file", $file );
            my $shortSourceName = $file;
            $shortSourceName =~ s!.*/!!;
            $shortSourceName =~ s!\.json$!!;

            my $usConfigJson = IndieBox::Utils::readJsonFromFile( $file );

			if( ! $usConfigJson->{type} ) {
				warn( "No type given in $file, skipping." );
				next;
			} elsif( $usConfigJson->{type} eq 'git' ) {
				$ret->{$shortSourceName} = new IndieBox::Macrobuild::GitUsConfig(
						$shortSourceName,
						$usConfigJson,
                        $file );
				
			} elsif( $usConfigJson->{type} eq 'download' ) {
				$ret->{$shortSourceName} = new IndieBox::Macrobuild::DownloadUsConfig(
						$shortSourceName,
						$usConfigJson,
                        $file );
			} else {
				warn( "Unknown type", $usConfigJson->{type}, "given in $file, skipping." );
				next;
			}
				

        }
    }
    return $ret;
}

1;

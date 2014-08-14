# 
# Applicable UpConfigs. This is only resolved after construction.
#

use strict;
use warnings;

package IndieBox::Macrobuild::UpConfigs;

use fields qw( dir settingsConfigsMap );

use IndieBox::Macrobuild::UpConfig;
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
            Macrobuild::Logging::debug( "No config files found in upstream packages config dir:", $self->{dir}, 'expanded to', $realDir );
            return undef;
        }

        $ret = {};
        $self->{settingsConfigsMap}->{$settings->getName} = $ret;

        foreach my $file ( @files ) {
            Macrobuild::Logging::info( "Now reading upstream packages config file", $file );
            my $shortRepoName = $file;
            $shortRepoName =~ s!.*/!!;
            $shortRepoName =~ s!\.json$!!;

            my $upConfigJson = IndieBox::Utils::readJsonFromFile( $file );
            my $directory    = $upConfigJson->{directory};
            my $packages     = $upConfigJson->{packages};

            unless( defined( $directory )) {
                warn( "No directory given in $file, skipping." );
                next;
            }
            $directory = $settings->replaceVariables( $directory );

            unless( !defined( $directory ) || ( $directory =~ m!^/! && -d $directory ) || $directory =~ m!^https?://! ) {
                warn( "No or invalid directory given in $file, skipping: ", $directory );
                next;
            }
            my $lastModified = (stat( $file ))[9];
            $ret->{$shortRepoName} = new IndieBox::Macrobuild::UpConfig( $shortRepoName, $lastModified, $directory, $packages );
        }
        return $ret;
    }
    return $ret;
}

1;

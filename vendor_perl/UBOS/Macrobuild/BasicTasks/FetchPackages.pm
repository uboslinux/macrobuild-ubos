#
# Build one or more packages.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::FetchPackages;

use base qw( Macrobuild::Task );
use fields qw( downloaddir );

use Macrobuild::Task;
use UBOS::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    unless( exists( $in->{'packages-to-download'} )) {
        error( "No packages-to-download given in input" );
        return FAIL;
    }
    my $toDownload  = $in->{'packages-to-download'};
    my $downloadDir = $run->getProperty( 'downloaddir' );

    my $downloaded  = {};
    my $haveAlready = {};
    if( %$toDownload ) {
        foreach my $upConfigName ( sort keys %$toDownload ) {
            my $upConfigDownloadData = $toDownload->{$upConfigName};
            my $upConfigDownloadDir  = "$downloadDir/$upConfigName";

            foreach my $packageName ( sort keys %$upConfigDownloadData ) {
                my $packageUrl = $upConfigDownloadData->{$packageName};

                my $localName = $packageUrl;
                $localName =~ s!(.*/)!!;

                my $fullLocalName = "$upConfigDownloadDir/$localName";
                if( -e $fullLocalName ) {
                    trace( 'Skipping download, exists already:', $fullLocalName );
                    $haveAlready->{$upConfigName}->{$packageName} = $fullLocalName;

                } else {
                    info( 'Fetching package', $packageName );

                    unless( UBOS::Utils::myexec( "curl -L -R -s -o '$fullLocalName' '$packageUrl'" )) {
                        $downloaded->{$upConfigName}->{$packageName} = $fullLocalName;
                    } else {
                        error( "Failed to download $packageUrl" );
                        return FAIL;
                    }
                }
                if( -e "$fullLocalName.sig" ) {
                    trace( 'Skipping download, exists already:', "$fullLocalName.sig" );

                } else {
                    trace( 'Fetching signature for package', $packageName );

                    if( UBOS::Utils::myexec( "curl -L -R -s -o '$fullLocalName.sig' '$packageUrl.sig'" )) {
                        warning( "Failed to download signature for $packageUrl" );
                    }
                }
            }
        }
    }

    $run->setOutput( {
            'new-packages' => $downloaded,
            'old-packages' => $haveAlready
    } );

    if( %$downloaded ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;


# 
# Build one or more packages.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::FetchPackages;

use base qw( Macrobuild::Task );
use fields qw( downloaddir );

use UBOS::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;
    
    my $in = $run->taskStarting( $self );

    unless( exists( $in->{'packages-to-download'} )) {
        error( "No packages-to-download given in input" );
        return -1;
    }
    my $toDownload = $in->{'packages-to-download'};
    
    my $downloaded  = {};
    my $haveAlready = {};
    if( %$toDownload ) {
        foreach my $repoName ( sort keys %$toDownload ) {
            my $repoDownloadData = $toDownload->{$repoName};

            my $repoDownloadDir = $run->{settings}->replaceVariables( $self->{downloaddir} ) . "/$repoName";
            
            foreach my $packageName ( sort keys %$repoDownloadData ) {
                my $packageUrl = $repoDownloadData->{$packageName};

                my $localName = $packageUrl;
                $localName =~ s!(.*/)!!;
                
                my $fullLocalName = "$repoDownloadDir/$localName";
                if( -e $fullLocalName ) {
                    debug( "Skipping download, exists already:", $fullLocalName );
                    $haveAlready->{$repoName}->{$packageName} = $fullLocalName;

                } else {
                    debug( "Downloading:", $fullLocalName, "from", $packageUrl );

                    unless( UBOS::Utils::myexec( "curl -s -L -o '$fullLocalName' '$packageUrl'" )) {
                        $downloaded->{$repoName}->{$packageName} = $fullLocalName;
                    } else {
                        error( "Failed to download $packageUrl" );
                        return -1;
                    }
                }
                if( -e "$fullLocalName.sig" ) {
                    debug( "Skipping download, exists already:", "$fullLocalName.sig" );

                } else {
                    debug( "Downloading:", "$fullLocalName.sig", "from", $packageUrl );

                    if( UBOS::Utils::myexec( "curl -s -L -o '$fullLocalName.sig' '$packageUrl.sig'" )) {
                        warning( "Failed to download signature for $packageUrl" );
                    }
                }
            }
        }
    }

    my $ret = 1;
    if( %$downloaded ) {
        $ret = 0;
    }

    $run->taskEnded(
            $self,
            {
                'new-packages' => $downloaded,
                'old-packages' => $haveAlready
            },
            $ret );

    return $ret;
}

1;


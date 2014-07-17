# 
# Build one or more packages.
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::FetchPackages;

use base qw( Macrobuild::Task );
use fields qw( downloaddir );

use Macrobuild::Logging;

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
    
    my $downloaded = {};
    if( %$toDownload ) {
        while( my( $repoName, $repoDownloadData ) = each %$toDownload ) {
            my $repoDownloadDir = $run->{settings}->replaceVariables( $self->{downloaddir} ) . "/$repoName";
            
            while( my( $packageName, $packageUrl ) = each %$repoDownloadData ) {
                my $localName = $packageUrl;
                $localName =~ s!(.*/)!!;
                
                my $fullLocalName = "$repoDownloadDir/$localName";
                if( -e $fullLocalName ) {
                    info( "Skipping download, exists already:", $fullLocalName );
                } else {
                    info( "Downloading:", $fullLocalName, "from", $packageUrl );

                    unless( IndieBox::Utils::myexec( "curl -s -L -o '$fullLocalName' '$packageUrl'" )) {
                        $downloaded->{$repoName}->{$packageName} = $fullLocalName;

                    } else {
                        IndieBox::Utils::error( "Failed to download $packageUrl" );
                        return -1;
                    } 
                }
            }
        }
    }

    $run->taskEnded( $self, {
            'new-packages' => $downloaded
    } );
    if( %$downloaded ) {
        return 0;
    } else {
        return 1;
    }
}

1;


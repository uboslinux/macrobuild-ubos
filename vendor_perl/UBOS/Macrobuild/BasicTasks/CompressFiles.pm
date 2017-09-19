#
# Compress files given by a glob, possible move the compressed files
# to a different directory, and adjust link-latest symlinks
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CompressFiles;

use base qw( Macrobuild::Task );
use fields qw( inDir glob outDir adjustSymlinks );

use Cwd qw( abs_path );
use File::Spec;
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $inDir          = $run->getProperty( 'inDir'  );
    my $glob           = $run->getProperty( 'glob'   );
    my $outDir         = $run->getProperty( 'outDir' );
    my $adjustSymlinks = !defined( $self->{adjustSymlinks} ) || $self->{adjustSymlinks};

    unless( -d $outDir ) {
        UBOS::Utils::mkdirDashP( $outDir );
    }

    my $command = 'xz --threads=0'; # use as many threads as there are CPU cores
    my $ext     = '.xz';

    my @allFiles             = glob "$inDir/$glob";
    my %localFilesToSymlinks = ();

    # assemble a hash of non-symlink files pointing to the symlinks referring to it.
    # while are at it, delete compressed files in the $inDir
    foreach my $file ( @allFiles ) {
        unless( -l $file ) {

            my $localFile = $file;
            $localFile =~ s!.*/!!;

            if( $localFile =~ m!$ext$! ) {
                info( 'Deleting compressed file in inDir, should not be here:', "$inDir/$localFile" );
                UBOS::Utils::deleteFile( "$inDir/$localFile" );
            } else {
                $localFilesToSymlinks{$localFile} = [];
            }
        }
    }

    foreach my $file ( @allFiles ) {
        if( -l $file ) {
            my $localFile = $file;
            $localFile =~ s!.*/!!;

            my $target = readlink( $file );
            if( $target =~ m!\.\.! || $target =~ m!/! ) {
                warning( 'Cannot deal with non-local symlink:', $file, '=>', $target );
                next;
            }

            if( exists( $localFilesToSymlinks{$target} )) {
                push @{$localFilesToSymlinks{$target}}, $localFile;

            } else {
                info( 'Skipping', $file, '=>', $target );
            }
        }
    }

    # for all non-symlink files
    my $ret = DONE_NOTHING;
    my @already    = ();
    my @compressed = ();
    if( keys %localFilesToSymlinks ) {
        foreach my $localFile ( keys %localFilesToSymlinks ) {
            if( -e "$outDir/$localFile$ext" ) {
                info( 'Already has a compressed companion in outDir, skipping compression:', "$inDir/$localFile" );
                push @already, "$outDir/$localFile$ext";

            } else {
                if( UBOS::Utils::myexec( "$command < '$inDir/$localFile' > '$outDir/$localFile$ext'" )) {
                    error( 'Compressing failed:', "$inDir/$localFile", '->', "$outDir/$localFile$ext" );
                    $ret = FAIL;
                } else {
                    $ret = SUCCESS;

                    push @compressed, "$outDir/$localFile$ext";
                    my @symlinks = @{$localFilesToSymlinks{$localFile}};
                    foreach my $symlink ( @symlinks ) { # may be empty
                        if( -l "$outDir/$symlink$ext" ) {
                            UBOS::Utils::deleteFile( "$outDir/$symlink$ext" );
                        }

                        info( 'Symlinking', "$localFile$ext", '<-', "$outDir/$symlink$ext" );
                        UBOS::Utils::symlink( "$localFile$ext", "$outDir/$symlink$ext" );
                    }
                }
            }
        }
    } else {
        warning( 'No files to compress when expanding glob', $glob, 'in directory', $inDir );
    }

    if( $ret == SUCCESS ) {
        $run->setOutput( {
                'files'      => [ map { "$inDir/$_" } keys %localFilesToSymlinks ],
                'compressed' => \@compressed
        } );
    }

    return $ret;
}

1;


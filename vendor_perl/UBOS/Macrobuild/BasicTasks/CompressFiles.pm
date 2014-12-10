# 
# Compress files given by a glob
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CompressFiles;

use base qw( Macrobuild::Task );
use fields qw( files keep adjustSymlinks );

use Cwd qw( abs_path );
use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $files          = $run->replaceVariables( $self->{files} );
    my $keep           = exists( $self->{keep} ) && $self->{keep};
    my $adjustSymlinks = exists( $self->{adjustSymlinks} ) && $self->{adjustSymlinks};

    my $command = 'xz';
    my $ext     = '.xz';

    if( $keep ) {
        $command .= ' --keep';
    }

    my @files = grep { ! -l $_ } glob $files;

    if( $adjustSymlinks ) {
        foreach my $file ( @files ) {
            my $absFile = abs_path( $file );
            my $dir     = $absFile;
            $dir =~ s!/[^/]+$!!;

            my @symlinks = grep { -l $_ } <$dir/*>;
            foreach my $symlink ( @symlinks ) {
                my $target = readlink( $symlink );
                unless( $target =~ m!/! ) {
                    # we don't do anything outside of our current dir
                    if( "$dir/$target" eq $absFile ) {
                        unless( $keep ) {
                            UBOS::Utils::deleteFile( $symlink );
                        }
                        UBOS::Utils::symlink( "$target$ext", "$symlink$ext" );
                    }
                }
            }
        }            
    }

    my $ret   = 0;
    if( @files ) {
        foreach my $file ( @files ) {
            if( UBOS::Utils::myexec( "$command '$file'" )) {
                error( 'Compressing failed:', $file );
                $ret = 1;
            }
        }
    } else {
        warning( 'No files to compress when expanding glob', $files );
    }
    
    if( $ret == 0 ) {
        $run->taskEnded(
                $self,
                { 'files' => \@files },
                $ret );
    } else {
        $run->taskEnded(
                $self,
                {},
                $ret );
    }

    return $ret;
}

1;


# 
# Compress files given by a glob
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CompressFiles;

use base qw( Macrobuild::Task );
use fields qw( files keep adjustSymlinks );

use Cwd qw( abs_path );
use File::Spec;
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

    my @allFiles        = glob $files;
    my %filesToSymlinks = ();

    foreach my $file ( @allFiles ) {
        unless( -l $file ) {
            my $absFile = abs_path( $file );
            $filesToSymlinks{$absFile} = [];
        }
    }

    foreach my $file ( @allFiles ) {    
        if( -l $file ) {
            my $absFile = File::Spec->rel2abs( $file ); # need of the symlink, not the target
            my $dir     = $absFile;
            $dir =~ s!/[^/]+$!!;

            my $target    = readlink( $absFile );
            my $absTarget = abs_path( "$dir/$target" );

            if( exists( $filesToSymlinks{$absTarget} )) {
                push @{$filesToSymlinks{$absTarget}}, $absFile;
                
            } else {
                info( 'Skipping', $absFile, '=>', $absTarget );
            }
            
        } else {
        }
    }

    my $ret = 1;
    my @already    = ();
    my @compressed = ();
    if( keys %filesToSymlinks ) {
        foreach my $file ( keys %filesToSymlinks ) {
            if( $file =~ m!$ext$! ) {
                info( 'Skipping compressed file', $file );

            } elsif( -l "$file" ) {
                info( 'Is a symlink, skipping', $file );

            } elsif( -e "$file$ext" ) {
                info( 'Already has a compressed companion, skipping', $file );
                push @already, $file;

            } else {
                if( UBOS::Utils::myexec( "$command '$file'" )) {
                    error( 'Compressing failed:', $file );
                    $ret = -1;
                } else {
                    $ret = 0;

                    push @compressed, $file;
                    my @symlinks = @{$filesToSymlinks{$file}};
                    foreach my $symlink ( @symlinks ) { # may be empty
                        unless( $keep ) {
                            UBOS::Utils::deleteFile( $symlink );
                        }
                        info( 'Symlinking', "$file$ext", '->', "$symlink$ext" );
                        UBOS::Utils::symlink( "$file$ext", "$symlink$ext" );
                    }
                }
            }
        }
    } else {
        warning( 'No files to compress when expanding glob', $files );
    }
    
    if( $ret == 0 ) {
        $run->taskEnded(
                $self,
                { 'files'      => [ keys %filesToSymlinks ],
                  'compressed' => \@compressed },
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


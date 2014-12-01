# 
# Purge a repository in a channel
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PurgeChannelRepository;

use base qw( Macrobuild::Task );
use fields qw( dir age );

use Cwd qw( abs_path );
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;
use UBOS::Macrobuild::PacmanDbFile;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $dir = abs_path( $run->replaceVariables( $self->{dir} ));
    my $age = $run->replaceVariables( $self->{age} );

    my $dbName = $dir;
    $dbName =~ s!(.*)/!!; # last component of the path
    $dbName .= '.db';

    my @keepList  = ();
    my @purgeList = ();
    my $ret       = 1;

    if( -e "$dir/$dbName" ) {
        # This might be a db not supported on this arch, such as virt on arm
        my @filesInDir = <$dir/*>;
        @filesInDir = map { s!^$dir/!!; $_ } @filesInDir;

        # categorize, so we can make a clean sweep
        my %packageFiles    = (); # hash of packageName to hash of file name to return from parsePackageFileName
        my %packageSigFiles = (); # hash of sig file to sig file
        my %uncategorized   = (); # hash of file to file
        foreach my $file ( @filesInDir ) {
            if( $file eq $dbName ) {
                next;
            } elsif( $file eq "$dbName.sig" ) {
                next;
            } elsif( $file eq "$dbName.tar.xz" ) {
                next;
            } elsif( $file eq "$dbName.tar.xz.old" ) {
                next;
            } elsif( $file eq "$dbName.tar.xz.old.sig" ) {
                next;
            } elsif( $file eq "$dbName.tar.xz.sig" ) {
                next;
            } elsif( $file =~ m!\.pkg\.tar\.[a-z]+\.sig$! ) {
                $packageSigFiles{$file} = $file;
            } else {
                my $parsed = UBOS::Macrobuild::PackageUtils::parsePackageFileName( $file );
                if( $parsed ) {
                    $packageFiles{$parsed->{name}}->{$file} = $parsed;
                } else {
                    $uncategorized{$file} = $file;
                }
            }
        }
        if( %uncategorized ) {
            warning( 'Found uncategorizable file(s) in dir', $dir, ':', keys %uncategorized );
        }

        # Find what files we should be having
        my $db       = new UBOS::Macrobuild::PacmanDbFile( "$dir/$dbName" );
        my $packages = $db->containedPackages;

        my $cutoff = time()- $age;

        foreach my $packageName ( keys %$packages ) {
            my $packageFile = $packages->{$packageName};
            unless( exists( $packageFiles{$packageName} )) {
                error( 'Cannot find any sign of package', $packageName, 'in dir', $dir, ', db wants file', $packageFile );
                next;
            }
            my $filesForPackage       = $packageFiles{$packageName};
            my @parsedFilesForPackage = values %$filesForPackage;
            my @orderedFilesForPackage = sort
                                         { UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion( $a, $b ) }
                                         @parsedFilesForPackage;
            @orderedFilesForPackage = map { $_->{original} } @orderedFilesForPackage;

            unless( exists( $filesForPackage->{$packageFile} )) {
                error( 'Cannot find package file in dir', $dir, ', db wants file', $packageFile );
                # so we better keep everything
                push @keepList,                map { "$dir/$_"     } @orderedFilesForPackage;
                push @keepList, grep { -e $_ } map { "$dir/$_.sig" } @orderedFilesForPackage;
                next;
            }

            push @keepList, "$dir/$packageFile";
            if( -e "$dir/$packageFile.sig" ) {
                push @keepList, "$dir/$packageFile.sig";
            }

            # now let's see what else to keep -- everything newer than the currently referenced package
            my $keep = 1;
            for( my $i=@orderedFilesForPackage-1 ; $i>=0 ; --$i ) {
                if( $packageFile eq $orderedFilesForPackage[$i] ) {
                    $keep = 0;
                    next;
                }
                if( $keep ) {
                    push @keepList, "$dir/" . $orderedFilesForPackage[$i];
                    if( -e "$dir/" . $orderedFilesForPackage[$i] . '.sig' ) {
                        push @keepList, "$dir/" . $orderedFilesForPackage[$i] . '.sig';
                    }
                } else {
                    my $mtime = ( lstat( "$dir/" . $orderedFilesForPackage[$i] ))[9];
                    if( $mtime < $cutoff ) {
                        push @purgeList, "$dir/" . $orderedFilesForPackage[$i];
                        if( -e "$dir/" . $orderedFilesForPackage[$i] . '.sig' ) {
                            push @purgeList, "$dir/" . $orderedFilesForPackage[$i] . '.sig';
                        }
                    } else {
                        push @keepList, "$dir/" . $orderedFilesForPackage[$i];
                        if( -e "$dir/" . $orderedFilesForPackage[$i] . '.sig' ) {
                            push @keepList, "$dir/" . $orderedFilesForPackage[$i] . '.sig';
                        }
                    }
                }
            }
        }

        debug( 'Keeping', @keepList );
        debug( 'Purging', @purgeList );

        if( @purgeList ) {
            if( UBOS::Utils::deleteFile( @purgeList )) {
                $ret = 0;
            } else {
                error( 'Failed to purge some files:', @purgeList );
                $ret = -1;
            }
        }
    }

    $run->taskEnded(
            $self,
            {
                'purged' => \@purgeList,
                'kept'   => \@keepList
            },
            $ret );
    return $ret;
}

1;

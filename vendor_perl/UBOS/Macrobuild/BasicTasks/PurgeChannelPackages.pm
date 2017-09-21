#
# Purge the packages in a channel
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PurgeChannelPackages;

use base qw( Macrobuild::Task );
use fields qw( dir maxAge );

use Cwd qw( abs_path );
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;
use UBOS::Macrobuild::PacmanDbFile;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $age = $self->getProperty( 'maxAge' );
    my $dir = $self->getProperty( 'dir' );
    unless( -d $dir ) {
        error( 'PurgeChannelPackages: directory does not exist:', $dir );
        return FAIL;
    }
    $dir = abs_path( $dir );

    my $dbName = $dir;
    $dbName =~ s!(.*)/!!; # last component of the path
    my $dbExt = '.db';

    my @keepList  = ();
    my @purgeList = ();
    my $ret       = DONE_NOTHING;

    if( -e "$dir/$dbName$dbExt" ) {
        # This might be a db not supported on this arch, such as virt on arm
        my @filesInDir = <$dir/*>;
        @filesInDir = map { s!^$dir/!!; $_ } @filesInDir;

        # categorize, so we can make a clean sweep
        my %packageFiles    = (); # hash of packageName to hash of file name to return from parsePackageFileName
        my %packageSigFiles = (); # hash of sig file to sig file
        my %uncategorized   = (); # hash of file to file
        outer: foreach my $file ( @filesInDir ) {
            foreach my $mainOrFiles( $dbExt, '.files' ) {
                foreach my $mainOrTar( '', '.tar' ) {
                    foreach my $mainOrCompressed( '', '.xz', '.gz' ) {
                        foreach my $mainOrOld( '', '.old' ) {
                            foreach my $mainOrSig( '', '.sig' ) {
                                if( $file eq "$dbName$mainOrFiles$mainOrTar$mainOrCompressed$mainOrOld$mainOrSig" ) {
                                    next outer;
                                }
                            }
                        }
                    }
                }
            }

            if( $file =~ m!\.pkg\.tar\.[a-z]+\.sig$! ) {
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
        my $db       = new UBOS::Macrobuild::PacmanDbFile( "$dir/$dbName$dbExt" );
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

        trace( 'Keeping', @keepList );
        trace( 'Purging', @purgeList );

        if( @purgeList ) {
            if( UBOS::Utils::deleteFile( @purgeList )) {
                $ret = SUCCESS;
            } else {
                error( 'Failed to purge some files:', @purgeList );
                $ret = FAIL;
            }
        }
    }

    $run->setOutput( {
            'purged' => \@purgeList,
            'kept'   => \@keepList
    } );

    return $ret;
}

1;


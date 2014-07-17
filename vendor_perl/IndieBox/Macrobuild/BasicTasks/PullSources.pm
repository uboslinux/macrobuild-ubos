# 
# Pull the sources of the packages we may have to build
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::PullSources;

use base qw( Macrobuild::Task );
use fields qw( usconfigs sourcedir );

use Macrobuild::Logging;
use Macrobuild::Utils;

my $failedstamp = ".build-in-progress-or-failed";

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $dirsToBuild = {};
    my $usConfigs   = $self->{usconfigs}->configs( $run->{settings} );
    foreach my $usConfig ( values %$usConfigs ) {
        Macrobuild::Logging::info( "Now processing upstream source config file", $usConfig->name );

        my $name        = $usConfig->name;
        my $url         = $usConfig->url;
        my $branch      = $usConfig->branch;
        my $directories = $usConfig->directories;

        my $sourceSourceDir = $run->replaceVariables( $self->{sourcedir} ) . "/$name";
        if( -d $sourceSourceDir ) {
            # Second or later update -- make sure the spec is still the same, if not, delete
            my $gitCmd = "git remote -v";
            my $out;
            my $err;
            IndieBox::Utils::myexec( "cd '$sourceSourceDir'; $gitCmd", undef, \$out );
            if( $out =~ m!^origin\s+\Q$url\E\s+\(fetch\)! ) {
                $out = undef;
                $gitCmd = "git checkout '$branch' ; git pull";
                IndieBox::Utils::myexec( "( cd '$sourceSourceDir'; $gitCmd )", undef, \$out, \$err ); # just swallow

                # Determine which of the directories had changes in them
                my @toBuild;
                foreach my $dir ( @$directories ) {
                    if( $out =~ m!^\s\Q$dir\E/! ) {
                        # git pull output seems to put a space at the beginning of any line that indicates a change
                        # we look for anything below $dir, i.e. $dir plus appended slash
                        push @toBuild, $dir;
                    } elsif( -e "$sourceSourceDir/$dir/$failedstamp" ) {
                        # build failed last time
                        push @toBuild, $dir;
                    }
                        
                }
                if( @toBuild ) {
                    $dirsToBuild->{$name} = \@toBuild;
                }
            } else {
                info( "Source spec as changed. Starting over\n" );
                IndieBox::Utils::deleteRecursively( $sourceSourceDir );
            }
        }
    
        unless( -d $sourceSourceDir ) {
            # First-time checkout

            Macrobuild::Utils::ensureParentDirectoriesOf( $sourceSourceDir );
            
            my $gitCmd = "git clone";
            if( $branch ) {
                $gitCmd .= " --branch $branch"; 
            }
            $gitCmd .= " --depth 1"; 
            $gitCmd .= " '$url' '$name'";
            my $err;
            if( IndieBox::Utils::myexec( "cd '" . $run->replaceVariables( $self->{sourcedir} ) . "'; $gitCmd", undef, undef, \$err )) {
                error( "Failed to clone via", $gitCmd );
            } else {
                $dirsToBuild->{$name} = $directories; # all of them
            }
        }
    }

    $run->taskEnded( $self, {
            'dirs-to-build' => $dirsToBuild
    } );
    if( %$dirsToBuild ) {
        return 0;
    } else {
        return 1;
    }
}

##
# Sort package files by version
sub sortByPackageVersion {
    my @names = shift;

    my $out;
    IndieBox::Utils::myexec( "pacsort " . join( " ", @names ), undef, \$out );

    my @ret = split "\n", $out;
    return @ret;
}

1;


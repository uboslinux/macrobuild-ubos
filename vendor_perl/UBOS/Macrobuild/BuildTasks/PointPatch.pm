#
# Take locally existing package files and inserts them into the package dbs.
# Useful for point patches.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PointPatch;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db builddir repodir dbSignKey packageFile );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::PointPatchDispatch;
use UBOS::Macrobuild::BasicTasks::Stage;
use UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Macrobuild::Utils;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    $self->{splitSplitTaskOutput} = 1;

    my $dbs = $self->getProperty( 'db' );
    unless( ref( $dbs )) {
        $dbs = [ $dbs ];
    }

    my $repoUpConfigs = {};
    my $repoUsConfigs = {};

    # create UpConfigs/UsConfigs
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
        $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us' );
    }

    $self->setSplitTask( UBOS::Macrobuild::BasicTasks::PointPatchDispatch->new(
            'name'        => 'Determine into which db packages go',
            'upconfigs'   => $repoUpConfigs,
            'usconfigs'   => $repoUsConfigs,
            'packageFile' => '${packageFile}',
            'splitPrefix' => 'patch-' ));

    my @buildTasksSequence = ();

    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );

        my $buildTaskName = "patch-$shortDb";

        my $t = Macrobuild::CompositeTasks::Sequential->new();
        $t->appendTask( UBOS::Macrobuild::BasicTasks::Stage->new(
                'name'        => 'Stage new packages in local repository',
                'stagedir'    => '${repodir}/${channel}/${arch}/' . $shortDb ));

        $t->appendTask( UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase->new(
                'name'        => 'Update package database with new packages',
                'dbfile'      => '${repodir}/${channel}/${arch}/' . $shortDb . '/' . $shortDb . '.db.tar.xz',
                'dbSignKey'   => '${dbSignKey}' ));

        $self->addParallelTask( $buildTaskName, $t );

        push @buildTasksSequence, $buildTaskName;
    }

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge update lists from dbs: ' . join( ' ', @$dbs ),
            'keys' => \@buildTasksSequence ));

    return $self;
}

1;

#
# Set up maven ready for building package for UBOS
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::SetupMaven;

use base qw( Macrobuild::Task );
use fields qw( m2builddir );

use Macrobuild::Task;
use Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $ret = DONE_NOTHING;

    my $m2BuildDir = $run->getPropertyOrUndef( 'm2builddir' );
    if( $m2BuildDir ) {

        unless( -d $m2BuildDir ) {
            if( -e $m2BuildDir ) {
                error( 'Cannot create directory', $m2BuildDir, ', something else is in the way' );
                $ret = FAIL;

            } elsif( UBOS::Utils::mkdirDashP( $m2BuildDir )) {
                $ret = SUCCESS;

            } else {
                error( 'Failed to create directory', $m2BuildDir );
                $ret = FAIL;
            }
        }
        if( -d $m2BuildDir ) {
            # write settings.xml file
            if( UBOS::Utils::saveFile( "$m2BuildDir/settings.xml", <<CONTENT )) {
<?xml version="1.0" encoding="UTF-8"?>

<!--
Automatically generated by UBOS::Macrobuild::BasicTasks::SetupMaven

Do not modify, your changes will be mercilessly overwritten.
-->

<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">

  <localRepository>$m2BuildDir/repository</localRepository>

  <interactiveMode>false</interactiveMode>

<!--
  <offline>true</offline>
-->
  <offline>false</offline>

</settings>
CONTENT
                $ret = SUCCESS;

            } else {
                error( 'Cannot write Maven settings file', "$m2BuildDir/settings.xml" );
                $ret = FAIL;
            }
        }
    }

    return $ret;
}

1;


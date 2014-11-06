# 
# Create a boot image for an emulated PC running on VirtualBox.
# For parameters, see UBOS::Macrobuild::BasicTasks::AbstractCreateBootImage.pm
# 
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateBootImage_pc_vbox;

use base qw( UBOS::Macrobuild::BasicTasks::CreateBootImage_pc );
use fields;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( @args );

    # We have a few more

    push @{$self->{installPackages}}, 'virtualbox-guest', 'cloud-init', 'rng-tools';
    push @{$self->{enableDbs}},       'virt';
    push @{$self->{startServices}},   'vboxservice', 'rngd', 'cloud-final';

    return $self;
}

1;

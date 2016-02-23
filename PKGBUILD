developer="http://indiecomputing.com/"
url="http://ubos.net/"
maintainer=$developer
pkgname=macrobuild-ubos
pkgver=0.175
pkgrel=6
pkgdesc="Macrobuild extensions and configuration for UBOS"
arch=('any')
license=('GPL')
depends=(
        'arch-install-scripts'
        'autoconf'
        'automake'
        'binutils'
        'bison'
        'btrfs-progs'
        'curl'
        'dosfstools'
        'fakeroot'
        'file'
        'findutils'
        'flex'
        'gawk'
        'gcc'
        'gettext'
        'git'
        'grep'
        'gzip'
        'libevent'
        'libtool'
        'm4'
        'macrobuild'
        'make'
        'maven'
        'multipath-tools'
        'pacman'
        'pacsane'
        'patch'
        'parted'
        'perl-http-date'
        'perl-module-build'
        'php'
        'pkg-config'
        'rsync'
        'sed'
        'setuptools'
        'sudo'
        'ubos-install'
        'ubos-perl-utils'
        'util-linux'
        'webapptest'
        'which'
)
optdepends=(
        'docker'
        'grub'
        'virtualbox'
)

options=('!strip')

package() {
    for d in Macrobuild Macrobuild/BasicTasks Macrobuild/BuildTasks Macrobuild/ComplexTasks; do
        mkdir -p $pkgdir/usr/lib/perl5/vendor_perl/UBOS/$d
        install -m644 $startdir/vendor_perl/UBOS/$d/*.pm $pkgdir/usr/lib/perl5/vendor_perl/UBOS/$d
    done
}

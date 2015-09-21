developer="http://indiecomputing.com/"
url="http://ubos.net/"
maintainer=$developer
pkgname=macrobuild-ubos
pkgver=0.154
pkgrel=3
pkgdesc="Macrobuild extensions and configuration for UBOS"
arch=('any')
license=('GPL')
depends=(
        'arch-install-scripts'
        'fakeroot'
        'btrfs-progs'
        'curl'
        'dosfstools'
        'gcc'
        'git'
        'macrobuild'
        'make'
        'maven'
        'multipath-tools'
        'parted'
        'pacsane'
        'perl-http-date'
        'perl-module-build'
        'php'
        'rsync'
        'setuptools'
        'ubos-install'
        'ubos-perl-utils'
        'util-linux'
)
optdepends=(
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

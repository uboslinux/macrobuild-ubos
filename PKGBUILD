developer="http://indiecomputing.com/"
url="http://ubos.net/"
maintainer=$developer
pkgname=macrobuild-ubos
pkgver=0.63
pkgrel=1
pkgdesc="Macrobuild extensions and configuration for UBOS"
arch=('any')
license=('GPL')
depends=(
        'macrobuild'
        'ubos-perl-utils'
        'virtualbox'
        'parted'
        'util-linux'
        'btrfs-progs'
        'arch-install-scripts'
        'grub'
        'curl'
        'git'
        'rsync'
        'perl-http-date'
        'multipath-tools'
)
options=('!strip')

package() {
    for d in Macrobuild Macrobuild/BasicTasks Macrobuild/BuildTasks Macrobuild/ComplexTasks; do
        mkdir -p $pkgdir/usr/lib/perl5/vendor_perl/UBOS/$d
        install -m644 $startdir/vendor_perl/UBOS/$d/*.pm $pkgdir/usr/lib/perl5/vendor_perl/UBOS/$d
    done

    mkdir -p -m755 $pkgdir/etc/$pkgname/keys
    install -m644 $startdir/keys/ubos-admin.pub $pkgdir/etc/$pkgname/keys
}

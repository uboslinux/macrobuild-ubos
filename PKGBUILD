pkgname=macrobuild-indiebox
pkgver=0.3
pkgrel=1
pkgdesc="Indie Box tasks for macrobuild"
arch=('any')
url="http://uboc.indiebox.net/"
license=('GPL')
groups=()
depends=( 'macrobuild' 'virtualbox' 'parted' 'util-linux' 'btrfs-progs' 'arch-install-scripts' 'grub' 'curl'  'git' 'rsync' 'perl-http-date' )
backup=()
source=()
options=('!strip')

package() {
    for d in Macrobuild Macrobuild/BasicTasks Macrobuild/BuildTasks Macrobuild/ComplexTasks; do
        mkdir -p $pkgdir/usr/lib/perl5/vendor_perl/IndieBox/$d
        install -m644 $startdir/vendor_perl/IndieBox/$d/*.pm $pkgdir/usr/lib/perl5/vendor_perl/IndieBox/$d
    done
}

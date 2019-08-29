developer="http://indiecomputing.com/"
url="http://ubos.net/"
maintainer=${developer}
pkgname=macrobuild-ubos
pkgver=0.297
pkgrel=1
pkgdesc="Macrobuild extensions and configuration for UBOS"
arch=('any')
license=('AGPL3')
depends=(
        'arch-install-scripts'
        'autoconf'
        'automake'
        'aws-cli'
        'binutils'
        'bison'
        'btrfs-progs'
        'cmake'
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
        'libtool'
        'm4'
        'macrobuild'
        'make'
        'maven'
        'npm'
        'pacman'
        'pacsane'
        'patch'
        'parted'
        'perl-http-date'
        'pkg-config'
        'rsync'
        'sed'
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
_vendor_perl=$(perl -V::vendorarch: | sed -e "s![' ]!!g")
options=('!strip')

package() {
    for d in Macrobuild Macrobuild/BasicTasks Macrobuild/BuildTasks Macrobuild/ComplexTasks; do
        install -D -m644 ${startdir}/vendor_perl/UBOS/${d}/*.pm -t ${pkgdir}${_vendor_perl}/UBOS/${d}/
    done

    install -D -m755 ${startdir}/bin/* -t ${pkgdir}/usr/share/macrobuild-ubos/bin/
}

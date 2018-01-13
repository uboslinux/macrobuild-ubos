developer="http://indiecomputing.com/"
url="http://ubos.net/"
maintainer=${developer}
pkgname=macrobuild-ubos
pkgver=0.252
pkgrel=1
pkgdesc="Macrobuild extensions and configuration for UBOS"
arch=('any')
license=('AGPL3')
depends=(
        'apache'
        'arch-install-scripts'
        'autoconf'
        'automake'
        'binutils'
        'bison'
        'boost'
        'boost-libs'
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
        'go-pie'
        'grep'
        'gzip'
        'libevent'
        'libmariadbclient'
        'libnetfilter_conntrack'
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
        'perl-module-build'
        'php'
        'pkg-config'
        'protobuf-c'
        'python'
        'python2'
        'python-setuptools'
        'python2-setuptools'
        'qt5-base'
        'qt5-tools'
        'ruby'
        'ruby-bundler'
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

    install -D -m755 ${startdir}/bin/print-dependencies.sh -t ${pkgdir}/usr/share/macrobuild-ubos/bin/
}

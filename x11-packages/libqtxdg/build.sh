TERMUX_PKG_HOMEPAGE=https://lxqt.github.io
TERMUX_PKG_DESCRIPTION="Qt6 implementation of freedesktop.org XDG specifications"
TERMUX_PKG_LICENSE="LGPL-2.1"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="4.0.0"
TERMUX_PKG_SRCURL="https://github.com/lxqt/libqtxdg/releases/download/${TERMUX_PKG_VERSION}/libqtxdg-${TERMUX_PKG_VERSION}.tar.xz"
TERMUX_PKG_SHA256=8c1b250de914b2e1fb451c213ee6f249b7b5729c85ac3283fd75615a47a66b62
TERMUX_PKG_DEPENDS="glib, libc++, qt6-qtbase, qt6-qtsvg"
TERMUX_PKG_BUILD_DEPENDS="lxqt-build-tools, qt6-qttools-cross-tools"
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DGLIB_GIO_UNIX_INCLUDE_DIR=$TERMUX_PREFIX/include/gio-unix-2.0
"
TERMUX_PKG_AUTO_UPDATE=true

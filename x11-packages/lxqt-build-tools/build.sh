TERMUX_PKG_HOMEPAGE=https://lxqt.github.io
TERMUX_PKG_DESCRIPTION="Building tools required by LXQt project"
TERMUX_PKG_LICENSE="BSD 3-Clause"
TERMUX_PKG_LICENSE_FILE="BSD-3-Clause"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="2.0.0"
TERMUX_PKG_SRCURL="https://github.com/lxqt/lxqt-build-tools/releases/download/${TERMUX_PKG_VERSION}/lxqt-build-tools-${TERMUX_PKG_VERSION}.tar.xz"
TERMUX_PKG_SHA256=4599c47d1db35e0bb91e62b672e3fb7eb2ec1fb4dafcab94599b0156f54e7f07
TERMUX_PKG_BUILD_DEPENDS="qt6-qtbase, qt6-qtbase-cross-tools"
TERMUX_PKG_PLATFORM_INDEPENDENT=true
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DLXQT_ETC_XDG_DIR=${TERMUX_PREFIX}/etc/xdg
"

TERMUX_PKG_HOMEPAGE=https://github.com/neovide/neovide
TERMUX_PKG_DESCRIPTION="No Nonsense Neovim Client in Rust"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux-user-repository"
TERMUX_PKG_VERSION="0.12.2"
TERMUX_PKG_SRCURL=https://github.com/neovide/neovide/archive/refs/tags/${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=5425c60454388651fd79757bde7c4d7499cdc49b375f7697b48d8366d45d08e4
TERMUX_PKG_DEPENDS="libc++"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_AUTO_UPDATE=true

termux_step_pre_configure() {
	termux_setup_rust

	rm -fv Cargo.lock

	: "${CARGO_HOME:=$HOME/.cargo}"
	export CARGO_HOME

	cargo fetch --target "${CARGO_TARGET_NAME}"

	local f
	for f in $CARGO_HOME/registry/src/*/winit-*/Cargo.toml; do
		echo "Patching ${f}"
		diff -u "${f}" <(sed -e 's/target_os = \\"android\\"/not(target_os = \\"android\\")/g' -e '/^android/d' -e '/^ndk/d' "${f}") || :
		sed \
			-e 's/target_os = \\"android\\"/not(target_os = \\"android\\")/g' \
			-e '/^android/d' \
			-e '/^ndk/d' \
			-i "${f}"
	done

	grep android-activity -nHR $CARGO_HOME/registry/src/*/*/Cargo.toml

	#CFLAGS="$CPPFLAGS"

	rm -fv Cargo.lock
}

termux_step_make() {
	cargo build --jobs "${TERMUX_MAKE_PROCESSES}" --target "${CARGO_TARGET_NAME}" --release
}

termux_step_make_install() {
	install -Dm755 -t "${TERMUX_PREFIX}/bin" "target/${CARGO_TARGET_NAME}/release/neovide"
}

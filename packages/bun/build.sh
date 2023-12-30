TERMUX_PKG_HOMEPAGE=https://bun.sh/
TERMUX_PKG_DESCRIPTION="JavaScript runtime, bundler, test runner, and package manager"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1.0.20"
TERMUX_PKG_SRCURL=git+https://github.com/oven-sh/bun
TERMUX_PKG_GIT_BRANCH="bun-v${TERMUX_PKG_VERSION}"

termux_step_pre_configure() {
	# https://github.com/oven-sh/bun/blob/main/Dockerfile
	termux_setup_cmake
	termux_setup_ninja
	termux_setup_nodejs
	termux_setup_zig

	export ARCH_NAME_RAW=
	export CPU_TARGET=
	case "${TERMUX_ARCH}" in
	aarch64) ARCH_NAME_RAW=arm64 ;;
	arm) ARCH_NAME_RAW=armv7l ;;
	i686) ARCH_NAME_RAW=i686 ;;
	x86_64) ARCH_NAME_RAW=x86_64 ;;
	esac
	export CPU_TARGET="generic"

	mkdir -p "${TERMUX_PKG_BUILDDIR}/src/deps"
	cp -f "${TERMUX_PKG_SRCDIR}/Makefile" "${TERMUX_PKG_BUILDDIR}"

	for dep in \
		c-ares \
		lol-html \
		mimalloc \
		zlib \
		libarchive \
		boringssl \
		base64 \
		zstd \
		ls-hpack \
		js_lexer \
	; do
	cp -fr "${TERMUX_PKG_SRCDIR}/src/deps/${dep}" "${TERMUX_PKG_BUILDDIR}/src/deps"
	case "${dep}" in
	js_lexer)
		zig run src/js_lexer/identifier_cache.zig
		rm -fr zig-cache
		;;
	*)
		make -C "${TERMUX_PKG_BUILDDIR}" -j "${TERMUX_MAKE_PROCESSES}" "${dep}"
		;;
	esac
	rm -fr "${TERMUX_PKG_BUILDDIR}/src/deps/${dep}"
	done

	rm -f "${TERMUX_PKG_BUILDDIR}/Makefile"

	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+="
	-DBUN_EXECUTABLE=echo
	"
}

TERMUX_PKG_HOMEPAGE=https://wasi.dev/
TERMUX_PKG_DESCRIPTION="Libc for WebAssembly programs built on top of WASI system calls"
TERMUX_PKG_LICENSE="Apache-2.0, BSD 2-Clause, MIT"
TERMUX_PKG_LICENSE_FILE="LICENSE, src/wasi-libc/LICENSE-MIT, src/wasi-libc/libc-bottom-half/cloudlibc/LICENSE"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="22"
TERMUX_PKG_SRCURL=git+https://github.com/WebAssembly/wasi-sdk
TERMUX_PKG_GIT_BRANCH=wasi-sdk-${TERMUX_PKG_VERSION}
TERMUX_PKG_PLATFORM_INDEPENDENT=true
TERMUX_PKG_NO_STATICSPLIT=true
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_HOSTBUILD=true
TERMUX_MAKE_PROCESSES=1

termux_step_host_build() {
	termux_setup_cmake
	termux_setup_ninja

	make -C $TERMUX_PKG_BUILDDIR -j $TERMUX_MAKE_PROCESSES package
	echo HOSTBUILD FINISH
}

termux_step_pre_configure() {
	termux_setup_cmake
	termux_setup_ninja
	termux_setup_rust

	if ! :; then
	if [[ "${TERMUX_ON_DEVICE_BUILD}" == "false" ]]; then
		# https://github.com/android/ndk/issues/1960
		# use NDK r26 new wasm target support to build
		# but need to fix non standard stdatomic.h without pollution
		rm -fr "${TERMUX_PKG_TMPDIR}/toolchain"
		mkdir -p "${TERMUX_PKG_TMPDIR}/toolchain"
		cp -fr "${TERMUX_STANDALONE_TOOLCHAIN}"/{bin,include,lib} \
			"${TERMUX_PKG_TMPDIR}/toolchain"
		sed \
			-e "s|#include <sys/cdefs.h>|//#include <sys/cdefs.h>|" \
			-i "${TERMUX_PKG_TMPDIR}"/toolchain/lib/clang/*/include/stdatomic.h \
			-i "${TERMUX_PKG_TMPDIR}"/toolchain/lib/clang/*/include/bits/stdatomic.h
		export CC="${TERMUX_PKG_TMPDIR}/toolchain/bin/clang"
		export CXX="${TERMUX_PKG_TMPDIR}/toolchain/bin/clang++"
		export PATH="${TERMUX_PKG_TMPDIR}/toolchain/bin:${PATH}"
	fi
	export AR=$(command -v llvm-ar)
	export NM=$(command -v llvm-nm)
	export INSTALL_DIR="${TERMUX_PREFIX}/share/wasi-sysroot"
	export NINJA_FLAGS="-j ${TERMUX_MAKE_PROCESSES}"

	sed \
		-e "s|CC=\$(BUILD_PREFIX).*|CC=$(dirname $CC)/clang \\\\|g" \
		-e "s|AR=\$(BUILD_PREFIX).*|AR=${AR} \\\\|g" \
		-e "s|NM=\$(BUILD_PREFIX).*|NM=${NM} \\\\|g" \
		-e "s|cp -R \$(ROOT_DIR)/build/llvm/|#cp -R \$(ROOT_DIR)/build/llvm/|g" \
		-i Makefile
	sed \
		-e "/^set(CMAKE_C_COMPILER .*/d" \
		-e "/^set(CMAKE_CXX_COMPILER .*/d" \
		-e "/^set(CMAKE_ASM_COMPILER .*/d" \
		-e "/^set(CMAKE_AR .*/d" \
		-e "/^set(CMAKE_NM .*/d" \
		-e "/^set(CMAKE_RANLIB .*/d" \
		-i wasi-sdk.cmake wasi-sdk-pthread.cmake
	fi

	mkdir -p build
	touch build/llvm.BUILT # use our own LLVM
	touch build/config.BUILT # use our own autoconf config.guess
	touch build/wasm-component-ld.BUILT # build ourselves
	touch build/version.BUILT

	python3 ./version.py dump | tee build/VERSION
}

termux_step_make_install() {
	cargo install wasm-component-ld@0.1.5 --target "${CARGO_TARGET_NAME}" --root "${TERMUX_PREFIX}"

	cp -fr "build/install/${TERMUX_PREFIX}" "$(dirname "${TERMUX_PREFIX}")"
	install -v -Dm644 -t "${TERMUX_PREFIX}/share/cmake" \
		wasi-sdk.cmake \
		wasi-sdk-pthread.cmake
	install -v -Dm644 -t "${TERMUX_PREFIX}/share/cmake/Platform" \
		cmake/Platform/WASI.cmake
}

TERMUX_PKG_HOMEPAGE=https://github.com/ldc-developers/ldc
TERMUX_PKG_DESCRIPTION="D programming language compiler, built with LLVM"
TERMUX_PKG_LICENSE="BSD 3-Clause"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION=(1.32.0)
TERMUX_PKG_VERSION+=(15.0.7)  # LLVM version
TERMUX_PKG_VERSION+=(2.103.0) # TOOLS version
TERMUX_PKG_VERSION+=(1.31.1)  # DUB version

TERMUX_PKG_SRCURL=(https://github.com/ldc-developers/ldc/releases/download/v${TERMUX_PKG_VERSION}/ldc-${TERMUX_PKG_VERSION}-src.tar.gz
		   https://github.com/ldc-developers/llvm-project/releases/download/ldc-v${TERMUX_PKG_VERSION[1]}/llvm-${TERMUX_PKG_VERSION[1]}.src.tar.xz
		   https://github.com/llvm/llvm-project/releases/download/llvmorg-${TERMUX_PKG_VERSION[1]}/libunwind-${TERMUX_PKG_VERSION[1]}.src.tar.xz
		   https://github.com/llvm/llvm-project/releases/download/llvmorg-${TERMUX_PKG_VERSION[1]}/cmake-${TERMUX_PKG_VERSION[1]}.src.tar.xz
		   https://github.com/dlang/tools/archive/v${TERMUX_PKG_VERSION[2]}.tar.gz
		   https://github.com/dlang/dub/archive/v${TERMUX_PKG_VERSION[3]}.tar.gz
		   https://github.com/ldc-developers/ldc/releases/download/v${TERMUX_PKG_VERSION}/ldc2-${TERMUX_PKG_VERSION}-linux-x86_64.tar.xz)
TERMUX_PKG_SHA256=(c4ee0bf91b416dd5641353d9b267b6a48600c499c782beb112d2e460e329beac
		   8409f2f86a8d30e4e5b0a5cbaf15ee4c95f3c85e85abe017694f0479fbbcd481
		   406d199ae3a16add84017f40458a5e7c31f9412937fcb518715af0a0eeafbc0c
		   8986f29b634fdaa9862eedda78513969fe9788301c9f2d938f4c10a3e7a3e7ea
		   591bf56d7c8aa45205a3533438fef5bd48007756446f5cf032fcabcc077afdd1
		   dce1b3f7d21f6b111830d849e6f417853bab66d9036df212aec237c1f724bc4f
		   5a7b22cfa31568504f3f36ed0f474415c2760bf71d478aca0896a6857c00ba5a)
# dub dlopen()s libcurl.so:
TERMUX_PKG_DEPENDS="binutils-bin, binutils-is-llvm | binutils, clang, libc++, libcurl, zlib"
TERMUX_PKG_BUILD_DEPENDS="binutils-cross"
TERMUX_PKG_NO_STATICSPLIT=true
TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_FORCE_CMAKE=true
TERMUX_DEBUG_BUILD=true
#These CMake args are only used to configure a patched LLVM
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DLLVM_ENABLE_ASSERTIONS=ON
-DLLVM_ENABLE_LIBEDIT=OFF
-DLLVM_ENABLE_PLUGINS=OFF
-DLLVM_ENABLE_TERMINFO=OFF
-DLLVM_ENABLE_UNWIND_TABLES=OFF
-DLLVM_ENABLE_ZSTD=OFF
-DLLVM_INCLUDE_BENCHMARKS=OFF
-DLLVM_INCLUDE_TESTS=OFF
-DLLVM_INCLUDE_TOOLS=OFF
-DLLVM_INCLUDE_UTILS=OFF
-DLLVM_TABLEGEN=$TERMUX_PKG_HOSTBUILD_DIR/bin/llvm-tblgen
-DPYTHON_EXECUTABLE=$(command -v python3)
-DLLVM_TARGETS_TO_BUILD='AArch64;ARM;WebAssembly;X86'
"

termux_step_post_get_source() {
	# Certain packages are not safe to build on device because their
	# build.sh script deletes specific files in $TERMUX_PREFIX.
	if $TERMUX_ON_DEVICE_BUILD; then
		termux_error_exit "Package '$TERMUX_PKG_NAME' is not safe for on-device builds."
	fi

	mv llvm-${TERMUX_PKG_VERSION[1]}.src llvm
	mv libunwind-${TERMUX_PKG_VERSION[1]}.src libunwind
	mv tools-${TERMUX_PKG_VERSION[2]} dlang-tools
	mv dub-${TERMUX_PKG_VERSION[3]} dub

	# https://github.com/llvm/llvm-project/issues/57573
	cp -r cmake-${TERMUX_PKG_VERSION[1]}.src/Modules/*cmake cmake/Modules

	LLVM_TRIPLE=${TERMUX_HOST_PLATFORM/-/--}
	if [ $TERMUX_ARCH = arm ]; then LLVM_TRIPLE=${LLVM_TRIPLE/arm-/armv7a-}; fi
}

termux_step_host_build() {
	termux_setup_cmake
	termux_setup_ninja

	# Build native llvm-tblgen, a prerequisite for cross-compiling LLVM
	cmake -GNinja $TERMUX_PKG_SRCDIR/llvm \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_INCLUDE_BENCHMARKS=OFF \
		-DLLVM_INCLUDE_TESTS=OFF \
		-DLLVM_INCLUDE_TOOLS=OFF \
		-DLLVM_INCLUDE_UTILS=OFF
	ninja -j $TERMUX_MAKE_PROCESSES llvm-tblgen
}

# Just before CMake invokation for LLVM:
termux_step_pre_configure() {
	PATH=$TERMUX_PREFIX/opt/binutils/cross/$TERMUX_HOST_PLATFORM/bin:$PATH

	LLVM_INSTALL_DIR=$TERMUX_PKG_BUILDDIR/llvm-install
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DCMAKE_INSTALL_PREFIX=$LLVM_INSTALL_DIR"

	if [ "$TERMUX_ARCH" == "arm" ]; then
		# [...]/ldc/src/llvm/projects/compiler-rt/lib/builtins/clear_cache.c:85:20:
		# error: write to reserved register 'R7'
		#   __asm __volatile("svc 0x0"
		#                    ^
		CFLAGS="${CFLAGS//-mthumb/}"
	fi
	LDFLAGS=" -L$TERMUX_PKG_BUILDDIR/llvm/lib $LDFLAGS -lc++_shared"

	# Don't build compiler-rt sanitizers:
	# * 64-bit targets: libclang_rt.hwasan-*-android.so fails to link
	# * 32-bit targets: compile errors for interception library
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF"

	local LLVM_TARGET_ARCH
	if [ $TERMUX_ARCH = "arm" ]; then
		LLVM_TARGET_ARCH=ARM
	elif [ $TERMUX_ARCH = "aarch64" ]; then
		LLVM_TARGET_ARCH=AArch64
	elif [ $TERMUX_ARCH = "i686" ]; then
		LLVM_TARGET_ARCH=X86
	elif [ $TERMUX_ARCH = "x86_64" ]; then
		LLVM_TARGET_ARCH=X86
	else
		termux_error_exit "Invalid arch: $TERMUX_ARCH"
	fi
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DLLVM_DEFAULT_TARGET_TRIPLE=${LLVM_TRIPLE}"
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DLLVM_TARGET_ARCH=${LLVM_TARGET_ARCH}"

	# CPPFLAGS adds the system llvm to the include path, which causes
	# conflicts with the local patched llvm when compiling ldc
	CPPFLAGS=""

	OLD_TERMUX_PKG_SRCDIR=$TERMUX_PKG_SRCDIR
	TERMUX_PKG_SRCDIR=$TERMUX_PKG_SRCDIR/llvm

	OLD_TERMUX_PKG_BUILDDIR=$TERMUX_PKG_BUILDDIR
	TERMUX_PKG_BUILDDIR=$TERMUX_PKG_BUILDDIR/llvm
	mkdir "$TERMUX_PKG_BUILDDIR"
}

# CMake for LLVM has been run:
termux_step_post_configure() {
	# Cross-compile & install LLVM
	cd "$TERMUX_PKG_BUILDDIR"
	if test -f build.ninja; then
		ninja -j $TERMUX_MAKE_PROCESSES install
	fi

	# Invoke CMake for LDC:

	TERMUX_PKG_SRCDIR=$OLD_TERMUX_PKG_SRCDIR
	TERMUX_PKG_BUILDDIR=$OLD_TERMUX_PKG_BUILDDIR
	cd "$TERMUX_PKG_BUILDDIR"

	# Replace non-native llvm-config executable with bash script,
	# as it is going to be invoked during LDC CMake config.
	sed $TERMUX_PKG_SRCDIR/.github/actions/3-build-cross/android-llvm-config.in \
		-e "s|@LLVM_VERSION@|${TERMUX_PKG_VERSION[1]}|g" \
		-e "s|@LLVM_INSTALL_DIR@|$LLVM_INSTALL_DIR|g" \
		-e "s|@TERMUX_PKG_SRCDIR@|$TERMUX_PKG_SRCDIR/llvm|g" \
		-e "s|@LLVM_DEFAULT_TARGET_TRIPLE@|$LLVM_TRIPLE|g" \
		-e "s|@LLVM_TARGETS@|AArch64 ARM X86 WebAssembly|g" > $LLVM_INSTALL_DIR/bin/llvm-config
	chmod 755 $LLVM_INSTALL_DIR/bin/llvm-config

	LDC_FLAGS="-mtriple=$LLVM_TRIPLE"

	LDC_PATH=$TERMUX_PKG_SRCDIR/ldc2-$TERMUX_PKG_VERSION-linux-x86_64
	DMD=$LDC_PATH/bin/ldmd2

	TERMUX_PKG_EXTRA_CONFIGURE_ARGS=" -DLLVM_ROOT_DIR=$LLVM_INSTALL_DIR \
		-DD_COMPILER=$DMD \
		-DCMAKE_INSTALL_PREFIX=$TERMUX_PREFIX \
		-DLDC_WITH_LLD=OFF \
		-DLDC_INSTALL_LLVM_RUNTIME_LIBS_OS=android \
		-DLDC_INSTALL_LLVM_RUNTIME_LIBS_ARCH=$TERMUX_ARCH-android \
		-DD_LINKER_ARGS='-fuse-ld=bfd;-Lldc-build-runtime.tmp/lib;-lphobos2-ldc;-ldruntime-ldc;-Wl,--gc-sections'"

	termux_step_configure_cmake
}

termux_step_make() {
	# Cross-compile the runtime libraries
	$LDC_PATH/bin/ldc-build-runtime --ninja -j $TERMUX_MAKE_PROCESSES \
		--dFlags="-fvisibility=hidden;$LDC_FLAGS" \
		--cFlags="-I$TERMUX_PREFIX/include" \
		--targetSystem="Android;Linux;UNIX" \
		--ldcSrcDir="$TERMUX_PKG_SRCDIR"

	# Set up host ldmd2 for cross-compilation
	export DFLAGS="${LDC_FLAGS//;/ }"

	# Cross-compile LDC executables (linked against runtime libs above)
	if test -f build.ninja; then
		ninja -j $TERMUX_MAKE_PROCESSES ldc2 ldmd2 ldc-build-runtime ldc-profdata ldc-prune-cache
	fi
	echo ".: LDC built successfully."

	# Cross-compile dlang tools and dub:

	# Extend DFLAGS for cross-linking with host ldmd2
	export DFLAGS="$DFLAGS -linker=bfd -L-L$TERMUX_PKG_BUILDDIR/ldc-build-runtime.tmp/lib"
	if [ $TERMUX_ARCH = arm ]; then export DFLAGS="$DFLAGS -L--fix-cortex-a8"; fi

	# https://github.com/termux/termux-packages/issues/7188
	DFLAGS+=" -L-rpath=$TERMUX_PREFIX/lib"

	cd  $TERMUX_PKG_SRCDIR/dlang-tools
	$DMD -w -de -dip1000 rdmd.d -of=$TERMUX_PKG_BUILDDIR/bin/rdmd
	$DMD -w -de -dip1000 ddemangle.d -of=$TERMUX_PKG_BUILDDIR/bin/ddemangle
	$DMD -w -de -dip1000 DustMite/dustmite.d DustMite/splitter.d DustMite/polyhash.d -of=$TERMUX_PKG_BUILDDIR/bin/dustmite
	echo ".: dlang tools built successfully."

	cd $TERMUX_PKG_SRCDIR/dub
	# Note: cannot link a native build.d tool, so build manually:
	$DMD -of=$TERMUX_PKG_BUILDDIR/bin/dub -Isource -version=DubUseCurl -version=DubApplication -O -w -linkonce-templates @build-files.txt
	echo ".: dub built successfully."
}

termux_step_make_install() {
	cp bin/{ddemangle,dub,dustmite,ldc-build-runtime,ldc-profdata,ldc-prune-cache,ldc2,ldmd2,rdmd} $TERMUX_PREFIX/bin
	cp $TERMUX_PKG_BUILDDIR/ldc-build-runtime.tmp/lib/*.a $TERMUX_PREFIX/lib
	cp lib/libldc_rt.* $TERMUX_PREFIX/lib || true
	sed "s|$TERMUX_PREFIX/|%%ldcbinarypath%%/../|g" bin/ldc2_install.conf > $TERMUX_PREFIX/etc/ldc2.conf

	rm -Rf $TERMUX_PREFIX/include/d
	mkdir $TERMUX_PREFIX/include/d
	cp -r $TERMUX_PKG_SRCDIR/runtime/druntime/src/{core,etc,ldc,object.d} $TERMUX_PREFIX/include/d
	cp $LDC_PATH/import/ldc/gccbuiltins_{aarch64,arm,x86}.di $TERMUX_PREFIX/include/d/ldc
	cp -r $TERMUX_PKG_SRCDIR/runtime/phobos/etc/c $TERMUX_PREFIX/include/d/etc
	rm -Rf $TERMUX_PREFIX/include/d/etc/c/zlib
	cp -r $TERMUX_PKG_SRCDIR/runtime/phobos/std $TERMUX_PREFIX/include/d

	rm -Rf $TERMUX_PREFIX/share/ldc
	mkdir $TERMUX_PREFIX/share/ldc
	cp -r $TERMUX_PKG_SRCDIR/{LICENSE,README,packaging/bash_completion.d} $TERMUX_PREFIX/share/ldc
}

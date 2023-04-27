TERMUX_PKG_HOMEPAGE=https://dotnet.microsoft.com/en-us/
TERMUX_PKG_DESCRIPTION=".NET 8"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="8.0.6"
TERMUX_PKG_SRCURL=git+https://github.com/dotnet/dotnet
TERMUX_PKG_GIT_BRANCH=v${TERMUX_PKG_VERSION}
TERMUX_PKG_DEPENDS="krb5, libandroid-glob, libicu, libllvm, liblzma, openssl, zlib"
TERMUX_PKG_BUILD_IN_SRC=true

termux_step_post_get_source() {
	# set up dotnet cli and override source files
	./prep.sh
}

termux_step_pre_configure() {
	termux_setup_cmake
	termux_setup_ninja
}

termux_step_configure() {
	export arch
	case "${TERMUX_ARCH}" in
	aarch64) arch=arm64 ;;
	arm) arch=arm ;;
	i686) arch=x86 ;;
	x86_64) arch=x64 ;;
	*) termux_error_exit "Unknown arch: ${TERMUX_ARCH}"
	esac

	export ANDROID_NDK_ROOT="${TERMUX_PKG_TMPDIR}"

	# unified sysroot needed when CMAKE_SYSROOT / --sysroot cannot be used
	export ROOTFS_DIR="${TERMUX_PKG_TMPDIR}/sysroot"
	rm -fr "${ROOTFS_DIR}"
	echo "INFO: Copying ${TERMUX_STANDALONE_TOOLCHAIN}/sysroot to ${ROOTFS_DIR}"
	cp -fr "${TERMUX_STANDALONE_TOOLCHAIN}/sysroot" "${ROOTFS_DIR}"
	echo "INFO: Copying ${TERMUX_PREFIX} to ${ROOTFS_DIR}"
	cp -fr "${TERMUX_PREFIX}" "${ROOTFS_DIR}"
	mv -v "${TERMUX_STANDALONE_TOOLCHAIN}"/sysroot{,.tmp}
	rm -fr "${TERMUX_STANDALONE_TOOLCHAIN}/sysroot.tmp"
	ln -sv "${ROOTFS_DIR}" "${TERMUX_STANDALONE_TOOLCHAIN}/sysroot"

	echo "RID=android.${TERMUX_PKG_API_LEVEL}-${arch}" > "${ROOTFS_DIR}/android_platform"

	# manual termux_step_configure_cmake
	CMAKE_PROC="${TERMUX_ARCH}"
	[[ "${CMAKE_PROC}" == "arm" ]] && CMAKE_PROC="armv7-a"
	export CFLAGS+=" -v --target=${CCTERMUX_HOST_PLATFORM}"
	export CXXFLAGS+=" -v --target=${CCTERMUX_HOST_PLATFORM}"

	# easier to embed in toolchain file than CMakeArgs
	mkdir -p "${TERMUX_PKG_TMPDIR}/build/cmake"
	cat <<- EOL > "${TERMUX_PKG_TMPDIR}/build/cmake/android.toolchain.cmake"
	set(CMAKE_C_FLAGS "\${CMAKE_C_FLAGS} ${CFLAGS}")
	set(CMAKE_CXX_FLAGS "\${CMAKE_CXX_FLAGS} ${CXXFLAGS}")
	set(CMAKE_SYSROOT "${ROOTFS_DIR}")
	set(CMAKE_C_COMPILER "${TERMUX_STANDALONE_TOOLCHAIN}/bin/${CC}")
	set(CMAKE_CXX_COMPILER "${TERMUX_STANDALONE_TOOLCHAIN}/bin/${CXX}")
	set(CMAKE_AR "$(command -v ${AR})")
	set(CMAKE_UNAME "$(command -v uname)")
	set(CMAKE_RANLIB "$(command -v ${RANLIB})")
	set(CMAKE_STRIP "$(command -v ${STRIP})")
	set(CMAKE_FIND_ROOT_PATH "${TERMUX_PREFIX}")
	set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM "NEVER")
	set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE "ONLY")
	set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY "ONLY")
	#set(CMAKE_INSTALL_PREFIX "${TERMUX_PREFIX}")
	#set(CMAKE_INSTALL_LIBDIR "${TERMUX_PREFIX}/lib")
	set(CMAKE_SKIP_INSTALL_RPATH "ON")
	set(CMAKE_USE_SYSTEM_LIBRARIES "True")
	set(CMAKE_CROSSCOMPILING "True")
	set(DOXYGEN_EXECUTABLE "")
	set(BUILD_TESTING "OFF")
	set(CMAKE_LINKER "${TERMUX_STANDALONE_TOOLCHAIN}/bin/${LD}")
	set(CMAKE_SYSTEM_NAME "Android")
	set(CMAKE_SYSTEM_VERSION "${TERMUX_PKG_API_LEVEL}")
	set(CMAKE_SYSTEM_PROCESSOR "${CMAKE_PROC}")
	set(CMAKE_ANDROID_STANDALONE_TOOLCHAIN "${TERMUX_STANDALONE_TOOLCHAIN}")
	# Android has no liblttng-ust
	# Linux also has issue https://github.com/dotnet/runtime/issues/57784
	#set(DISABLE_EVENTPIPE 1)
	#set(FEATURE_EVENT_TRACE 0)
	#set(FEATURE_PERFTRACING 0)
	EOL

	echo "===== android.toolchain.cmake ====="
	cat "${TERMUX_PKG_TMPDIR}/build/cmake/android.toolchain.cmake"
	echo "===== android.toolchain.cmake ====="


	export _EXTRA_ARGS=()
	if [[ "${TERMUX_DEBUG_BUILD}" == "true" ]]; then
		_EXTRA_ARGS+=("/p:Configuration=Debug")
	else
		_EXTRA_ARGS+=("/p:Configuration=Release")
	fi
	_EXTRA_ARGS+=("/p:CrossBuild=True")
	_EXTRA_ARGS+=("/p:TargetArchitecture=${arch}")
	# TODO hardcode for now
	_EXTRA_ARGS+=("/p:BuildArchitecture=x64")
	_EXTRA_ARGS+=("/p:TargetOS=android")
	_EXTRA_ARGS+=("/p:CleanWhileBuilding=true")
	_EXTRA_ARGS+=("/p:BuildWithOnlineSources=true")
	_EXTRA_ARGS+=("/p:MonoLibClang=${TERMUX_STANDALONE_TOOLCHAIN}/lib/libclang.so")
	_EXTRA_ARGS+=("/p:FeaturePerfTracing=false")

	#find / -name "libclang*.so*" 2>/dev/null | sort

	export _CMAKE_ARGS=""
	_CMAKE_ARGS="${_CMAKE_ARGS// /%20}"
	_EXTRA_ARGS+=("/p:CMakeArgs=\"${_CMAKE_ARGS}\"")

	export EXTRA_CFLAGS="${CFLAGS}"
	export EXTRA_CXXFLAGS="${CXXFLAGS}"
	export EXTRA_LDFLAGS="${LDFLAGS}"

	unset CC CFLAGS CXX CXXFLAGS LD LDFLAGS PKGCONFIG PKG_CONFIG PKG_CONFIG_DIR PKG_CONFIG_LIBDIR
}

termux_step_make() {
	pushd src/runtime/eng
	#(
	#if [[ "${arch}" == "x64" ]]; then
	#	./build.sh --cross --arch "${arch}" ${_EXTRA_ARGS[@]}
	#else
	#	./build.sh --cross --arch "${arch}" ${_EXTRA_ARGS[@]}
	#fi
	#) || :
	#find /tmp -name "*.log" -exec echo "===== {} =====" \; -a -exec cat "{}" \; -a echo "===== {} =====" \;
	#echo "========== end of t =========="
	#exit 1
	./build.sh --cross --arch $arch --subset clr
	#./build.sh --cross --arch $arch --subset libraries
	#./build.sh --cross --arch $arch --subset installer
}

termux_step_post_make_install() {
	mkdir -p $TERMUX_PREFIX/opt/dotnet8
	cp -fr $TERMUX_PKG_BUILDDIR $TERMUX_PREFIX/opt/dotnet8
	du -sh $TERMUX_PREFIX/opt/dotnet8
}

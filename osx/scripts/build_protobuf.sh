#!/usr/bin/env bash
set -e -u
set -o pipefail
mkdir -p ${PACKAGES}
cd ${PACKAGES}

download protobuf-${PROTOBUF_VERSION}.tar.bz2

if [[ "${TRAVIS_COMMIT:-false}" != false ]]; then
    if [[ "${CXX#*'clang'}" != "$CXX" ]]; then
        JOBS=4
    else
        JOBS=2
    fi
fi

echoerr 'building protobuf C++'
rm -rf protobuf-${PROTOBUF_VERSION}-${ARCH_NAME}
tar xf protobuf-${PROTOBUF_VERSION}.tar.bz2
mv protobuf-${PROTOBUF_VERSION} protobuf-${PROTOBUF_VERSION}-${ARCH_NAME}
cd protobuf-${PROTOBUF_VERSION}-${ARCH_NAME}
if [ $BOOST_ARCH = "arm" ]; then
    OLD_PLATFORM=${MASON_PLATFORM}
    MASON_CROSS=1 source ${ROOTDIR}/${HOST_PLATFORM}.sh
    NATIVE_PROTOC="${PACKAGES}/protobuf-${PROTOBUF_VERSION}-${ARCH_NAME}/src/protoc"
    MASON_CROSS=1 source ${ROOTDIR}/${OLD_PLATFORM}.sh
    if [ ! -f "${NATIVE_PROTOC}" ]; then
        echoerr 'native/host arch protoc missing, building now in subshell'
        OLD_PLATFORM=${MASON_PLATFORM}
        MASON_CROSS=1 source ${ROOTDIR}/${HOST_PLATFORM}.sh && ${ROOTDIR}/scripts/build_protobuf.sh
        MASON_CROSS=1 source ${ROOTDIR}/${OLD_PLATFORM}.sh
    fi
    CROSS_FLAGS="--with-protoc=${NATIVE_PROTOC}"
else
    CROSS_FLAGS=""
fi
LDFLAGS="${STDLIB_LDFLAGS} ${LDFLAGS}"
CXXFLAGS="${CXXFLAGS} -Wno-unused-local-typedefs -Wno-unknown-warning-option"

# note: we put ${STDLIB_CXXFLAGS} into CXX instead of CXXFLAGS due to libtool oddity:
# http://stackoverflow.com/questions/16248360/autotools-libtool-link-library-with-libstdc-despite-stdlib-libc-option-pass
CXX="${CXX} ${STDLIB_CXXFLAGS}"
# WARNING: building a shared lib will result in shared libs being listed in
# the libprotobuf.la and then libproto-c will try to link against them even
# if they do not exist (as deleted by below)
./configure --prefix=${BUILD} ${HOST_ARG} ${CROSS_FLAGS} \
--enable-static --disable-shared \
--disable-debug --without-zlib \
--disable-dependency-tracking
$MAKE -j${JOBS}
$MAKE install
if [ $BOOST_ARCH = "arm" ]; then
    cp "${NATIVE_PROTOC}" ${BUILD}/bin/
fi
cd ${PACKAGES}

#check_and_clear_libs

: '
Note: iPhoneSimulator not working atm:

dyld: Symbol not found: __ZNSt9exceptionD2Ev
  Referenced from: /Users/dane/projects/mapnik-packaging/osx/out/packages/protobuf-2.5.0-i386/src/protoc
  Expected in: /usr/lib/libc++abi.dylib

'

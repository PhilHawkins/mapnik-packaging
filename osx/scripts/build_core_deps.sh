set -e 

mkdir -p ${BUILD}
cd ${PACKAGES}


# xz
echo '*building xz*'
tar xf xz-5.0.3.tar.bz2
cd xz-5.0.3
./configure
make -j$JOBS
make install
cd ${PACKAGES}

# nose
wget http://pypi.python.org/packages/source/n/nose/nose-1.2.1.tar.gz
tar xf nose-1.2.1.tar.gz
cd nose-1.2.1
rm distribute_setup.py
wget http://python-distribute.org/distribute_setup.py
#sudo python3.3 setup.py install
# sudo will hang script
#sudo python setup.py install
cd ${PACKAGES}

# bzip2
echo '*building bzip2'
tar xf bzip2-${BZIP2_VERSION}.tar.gz
cd bzip2-${BZIP2_VERSION}
make
make install PREFIX=${BUILD} CC="$CC" CFLAGS="$CFLAGS"
cd ${PACKAGES}

# zlib
echo '*building zlib*'
tar xf zlib-${ZLIB_VERSION}.tar.gz
cd zlib-${ZLIB_VERSION}
./configure --prefix=${BUILD} --static --64
make -j$JOBS
make install
cd ${PACKAGES}

# freetype
echo '*building freetype*'
tar xf freetype-${FREETYPE_VERSION}.tar.bz2
cd freetype-${FREETYPE_VERSION}
./configure --prefix=${BUILD} --enable-static --disable-shared --disable-dependency-tracking
make -j${JOBS}
make install
cd ${PACKAGES}

# libpng
echo '*building libpng*'
tar xf libpng-${LIBPNG_VERSION}.tar.gz
cd libpng-${LIBPNG_VERSION}
./configure --prefix=${BUILD} --enable-static --disable-shared --disable-dependency-tracking
make -j${JOBS}
make install
cd ${PACKAGES}


# libxml2
echo '*building libxml2*'
tar xf libxml2-${LIBXML2_VERSION}.tar.gz
cd libxml2-${LIBXML2_VERSION}
patch threads.c ../../patches/libxml2-pthread.diff
./configure --prefix=${BUILD} --with-zlib=${PREFIX} \
--enable-static --disable-shared \
--with-icu=${PREFIX} \
--with-xptr \
--with-xpath \
--with-xinclude \
--with-threads \
--with-tree \
--with-catalog \
--without-legacy \
--without-iconv \
--without-debug \
--without-docbook \
--without-ftp \
--without-html \
--without-http \
--without-sax1 \
--without-schemas \
--without-schematron \
--without-valid \
--without-writer \
--without-modules \
--without-lzma \
--without-readline \
--without-regexps \
--without-c14n
make -j${JOBS}
make install
cd ${PACKAGES}

# libtool - for libltdl
tar xf libtool-${LIBTOOL_VERSION}.tar.gz
cd libtool-${LIBTOOL_VERSION}
./configure --prefix=${BUILD} --enable-static --disable-shared
make -j$JOBS
make install
cd ${PACKAGES}

# icu
echo '*building icu*'
# *WARNING* do not set an $INSTALL variable
# it will screw up icu build scripts
export OLD_CPPFLAGS=${CPPFLAGS}
export CPPFLAGS="-DU_CHARSET_IS_UTF8=1" # to try to reduce icu library size (18.3)
tar xf icu4c-${ICU_VERSION2}-src.tgz
cd icu/source
./runConfigureICU MacOSX --prefix=${BUILD} \
--disable-samples \
--enable-static \
--disable-shared \
--with-library-bits=64 \
--with-data-packaging=archive
make -j${JOBS}
make install
export CPPFLAGS=${OLD_CPPFLAGS}
cd ${PACKAGES}


# boost
echo '*building boost*'
B2_VERBOSE=""
#B2_VERBOSE="-d2"
tar xjf boost_${BOOST_VERSION2}.tar.bz2
cd boost_${BOOST_VERSION2}
# patch python build to ensure we do not link boost_python to python
patch tools/build/v2/tools/python.jam < ${ROOTDIR}/patches/python_jam.diff
./bootstrap.sh

# https://svn.boost.org/trac/boost/ticket/6686
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    patch tools/build/v2/tools/darwin.jam ${ROOTDIR}/patches/boost_sdk.diff
fi

# static libs
./b2 tools/bcp \
  --prefix=${BUILD} -j${JOBS} ${B2_VERBOSE} \
  --with-thread \
  --with-filesystem \
  --disable-filesystem2 \
  --with-program_options --with-system --with-chrono \
  toolset=darwin \
  address-model=64 \
  architecture=x86 \
  link=static \
  variant=release \
  stage install \
  linkflags="$LDFLAGS -L$BUILD/lib -licudata -licuuc" \
  cxxflags="$CXXFLAGS -DU_STATIC_IMPLEMENTATION=1" \
  -sHAVE_ICU=1 -sICU_PATH=${BUILD} \
  --with-regex

# regex separately
: '
./b2 --prefix=${BUILD} -j${JOBS} ${B2_VERBOSE} \
  linkflags="$LDFLAGS -L$BUILD/lib -licudata -licuuc" \
  cxxflags="$CXXFLAGS -DU_STATIC_IMPLEMENTATION=1" \
  --with-regex \
  toolset=darwin \
  macosx-version=${MIN_SDK_VERSION} \
  address-model=64 \
  architecture=x86 \
  link=static \
  variant=release \
  -sHAVE_ICU=1 -sICU_PATH=${BUILD} \
  stage install
'

#cp stage/lib/libboost_regex.dylib ${BUILD}/lib/libboost_regex-mapnik.dylib
#install_name_tool -id @loader_path/libboost_regex-mapnik.dylib ${BUILD}/lib/libboost_regex-mapnik.dylib
#ln -s ${BUILD}/lib/libboost_regex-mapnik.dylib ${BUILD}/lib/libboost_regex.dylib

# python

: '
./b2 --prefix=${BUILD} -j${JOBS} ${B2_VERBOSE} \
  --with-python \
  toolset=darwin \
  macosx-version=${MIN_SDK_VERSION} \
  address-model=32_64 \
  architecture=x86 \
  link=shared \
  variant=release \
  -sHAVE_ICU=1 -sICU_PATH=${BUILD} \
  stage install
'

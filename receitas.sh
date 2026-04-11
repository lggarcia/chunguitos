#!/bin/bash
####################################
#       __    ______  ______       #
#      |  |  |  ____||  ____|      #
#      |  |  | | __  | | __        #
#      |  |__| ||_ | | ||_ |       #
#      |_____|\____| |_____|       #
# -------------------------------- #
#   >> https://lucianogg.info      #
####################################
#     Script p/ LFS Project        #
####################################
# ------------------------------------------------------------------
# File: receitas.sh
# Description: Contains specific build instructions (recipes) for each package.
#              The function names map directly to 'id_receita' in pacotes.csv.
# ------------------------------------------------------------------

# === HELPER FUNCTIONS ===

aplicar_patch() {
    local nome_patch="$1"
    if [ -f "../$nome_patch" ]; then
        echo "   [Recipe] Applying patch: $nome_patch"
        patch -Np1 -i "../$nome_patch"
    else
        echo "   [Recipe] Warning: Patch $nome_patch not found."
    fi
}

receita_generica() {
    echo "   [Recipe] Executing GENERIC fallback build..."
    if [ -f "./configure" ]; then
        ./configure --prefix=/usr
    fi
    make -j$(nproc)
    make install
}

# ==================================================================
# CHAPTER 5: Compiling a Cross-Toolchain
# ==================================================================

# ID: binutils_pass1
binutils_pass1() {
    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    echo "Configuring Binutils (Pass 1)..."
    ../configure --prefix=$LFS/tools \
                 --with-sysroot=$LFS \
                 --target=$LFS_TGT   \
                 --disable-nls       \
                 --enable-gprofng=no \
                 --disable-werror    \
                 --enable-default-hash-style=gnu

    echo "Compiling..."
    make -j$(nproc)

    echo "Installing..."
    make install
}

# ID: gcc_pass1
gcc_pass1() {
    tar -xf ../mpfr-*.tar.xz
    mv -v mpfr-* mpfr
    tar -xf ../gmp-*.tar.xz
    mv -v gmp-* gmp
    tar -xf ../mpc-*.tar.gz
    mv -v mpc-* mpc

    case $(uname -m) in
        x86_64)
            sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
            ;;
    esac

    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    echo "Configuring GCC (Pass 1)..."
    ../configure --target=$LFS_TGT          \
                 --prefix=$LFS/tools        \
                 --with-glibc-version=2.41  \
                 --with-sysroot=$LFS        \
                 --with-newlib              \
                 --without-headers          \
                 --enable-default-pie       \
                 --enable-default-ssp       \
                 --disable-nls              \
                 --disable-shared           \
                 --disable-multilib         \
                 --disable-threads          \
                 --disable-libatomic        \
                 --disable-libgomp          \
                 --disable-libquadmath      \
                 --disable-libssp           \
                 --disable-libvtv           \
                 --disable-libstdcxx        \
                 --enable-languages=c,c++

    echo "Compiling..."
    make -j$(nproc)

    echo "Installing..."
    make install

    # Fix limits.h
    cd ..
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
	  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
}

# ID: linux_headers
linux_headers() {
    echo "Cleaning kernel tree..."
    make mrproper

    echo "Installing headers..."
    make headers
    find usr/include -type f ! -name '*.h' -delete

    echo "Copying to $LFS/usr..."
    cp -rv usr/include $LFS/usr
}

# ID: glibc
glibc() {
    # Create symlinks for FHS compliance
    case $(uname -m) in
        i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-linux.so.2 ;;
        x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-linux-x86-64.so.2 ;;
    esac

    patch -Np1 -i ../glibc-2.41-fhs-1.patch

    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    echo "Configuring Glibc..."
    ../configure                             \
        --prefix=/usr                        \
        --host=$LFS_TGT                      \
        --build=$(../scripts/config.guess)   \
        --enable-kernel=4.19                 \
        --with-headers=$LFS/usr/include      \
        --disable-nscd                       \
        libc_cv_slibdir=/usr/lib

    echo "Compiling..."
    make -j$(nproc)

    echo "Installing..."
    make DESTDIR=$LFS install

    # Sanity fix for ldd
    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

    echo "Verifying Compilation..."
    echo 'int main(){}' > dummy.c
    $LFS_TGT-gcc dummy.c
    readelf -l a.out | grep ': /lib'
    rm -v a.out dummy.c
}

# ID: libstdcpp_pass1
libstdcpp_pass1() {
    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    echo "Configuring Libstdc++..."
    ../libstdc++-v3/configure           \
        --host=$LFS_TGT                 \
        --build=$(../config.guess)      \
        --prefix=/usr                   \
        --disable-multilib              \
        --disable-nls                   \
        --disable-libstdcxx-pch         \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/14.2.0

    echo "Compiling..."
    make -j$(nproc)

    echo "Installing..."
    make DESTDIR=$LFS install

    rm -v $LFS/usr/lib/lib{stdc++,stdc++fs,supc++}.la
}

# ==================================================================
# CHAPTER 6: Cross Compiling Temporary Tools
# ==================================================================

# ID: m4_temp
m4_temp() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: ncurses_temp
ncurses_temp() {
    sed -i s/mawk// configure
    mkdir build
    pushd build
      ../configure
      make -C include
      make -C progs tic
    popd

    ./configure --prefix=/usr                \
                --host=$LFS_TGT              \
                --build=$(./config.guess)    \
                --mandir=/usr/share/man      \
                --with-manpage-format=normal \
                --with-shared                \
                --without-debug              \
                --without-ada                \
                --without-normal             \
                --disable-stripping          \
                --enable-widec

    make -j$(nproc)
    make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install

    echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
}

# ID: bash_temp
bash_temp() {
    ./configure --prefix=/usr                   \
                --build=$(support/config.guess) \
                --host=$LFS_TGT                 \
                --without-bash-malloc
    make -j$(nproc)
    make DESTDIR=$LFS install

    ln -sv bash $LFS/bin/sh
}

# ID: coreutils_temp
coreutils_temp() {
    ./configure --prefix=/usr                     \
                --host=$LFS_TGT                   \
                --build=$(build-aux/config.guess) \
                --enable-install-program=hostname \
                --enable-no-install-program=kill,uptime
    make -j$(nproc)
    make DESTDIR=$LFS install

    mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
    mkdir -pv $LFS/usr/share/man/man8
    mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
}

# ID: diffutils_temp
diffutils_temp() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(./build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: file_temp
file_temp() {
    mkdir build
    pushd build
      ../configure --disable-bzlib      \
                   --disable-libseccomp \
                   --disable-xzlib      \
                   --disable-zlib
      make
    popd

    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
    make FILE_COMPILE=$(pwd)/build/src/file
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/libmagic.la
}

# ID: findutils_temp
findutils_temp() {
    ./configure --prefix=/usr                   \
                --localstatedir=/var/lib/locate \
                --host=$LFS_TGT                 \
                --build=$(build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: gawk_temp
gawk_temp() {
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: grep_temp
grep_temp() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(./build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: gzip_temp
gzip_temp() {
    ./configure --prefix=/usr --host=$LFS_TGT
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: make_temp
make_temp() {
    ./configure --prefix=/usr   \
                --without-guile \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: patch_temp
patch_temp() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: sed_temp
sed_temp() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: tar_temp
tar_temp() {
    ./configure --prefix=/usr                     \
                --host=$LFS_TGT                   \
                --build=$(build-aux/config.guess)
    make -j$(nproc)
    make DESTDIR=$LFS install
}

# ID: xz_temp
xz_temp() {
    ./configure --prefix=/usr                     \
                --host=$LFS_TGT                   \
                --build=$(build-aux/config.guess) \
                --disable-static                  \
                --docdir=/usr/share/doc/xz-5.6.1
    make -j$(nproc)
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/liblzma.la
}

# ID: binutils_pass2
binutils_pass2() {
    sed '6009s/$add_dir//' -i ltmain.sh
    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    echo "Configuring Binutils (Pass 2)..."
    ../configure --prefix=/usr              \
                 --build=$(../config.guess) \
                 --host=$LFS_TGT            \
                 --disable-nls              \
                 --enable-shared            \
                 --enable-gprofng=no        \
                 --disable-werror           \
                 --enable-64-bit-bfd        \
                 --enable-default-hash-style=gnu

    make -j$(nproc)
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
}

# ID: gcc_pass2
gcc_pass2() {
    # Unpack dependencies AGAIN (required because we are in a fresh extraction)
    echo "   [Recipe] Unpacking GCC dependencies..."
    tar -xf ../mpfr-*.tar.xz
    mv -v mpfr-* mpfr
    tar -xf ../gmp-*.tar.xz
    mv -v gmp-* gmp
    tar -xf ../mpc-*.tar.gz
    mv -v mpc-* mpc

    # x86_64 adjustment
    case $(uname -m) in
        x86_64)
            sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
            ;;
    esac

    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    echo "Configuring GCC (Pass 2)..."
    ../configure --build=$(../config.guess)             \
                 --host=$LFS_TGT                        \
                 --target=$LFS_TGT                      \
                 LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc \
                 --prefix=/usr                          \
                 --with-build-sysroot=$LFS              \
                 --enable-default-pie                   \
                 --enable-default-ssp                   \
                 --disable-nls                          \
                 --disable-multilib                     \
                 --disable-libatomic                    \
                 --disable-libgomp                      \
                 --disable-libquadmath                  \
                 --disable-libvtv                       \
                 --enable-languages=c,c++

    make -j$(nproc)
    make DESTDIR=$LFS install

    ln -sv gcc $LFS/usr/bin/cc
}

# ==================================================================
# FASE 2: Building the Final System (Chapters 7 & 8)
# ==================================================================

# ID: gettext_temp
gettext_temp() {
    ./configure --disable-shared
    make -j$(nproc)
    cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
}

# ID: bison_temp
bison_temp() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
    make -j$(nproc)
    make install
}

# ID: perl_temp
perl_temp() {
    sh Configure -des                                         \
                 -Dprefix=/usr                                \
                 -Dvendorprefix=/usr                          \
                 -Duseshrplib                                 \
                 -Dprivlib=/usr/lib/perl5/5.40/core_perl      \
                 -Darchlib=/usr/lib/perl5/5.40/core_perl      \
                 -Dsitelib=/usr/lib/perl5/5.40/site_perl      \
                 -Dsitearch=/usr/lib/perl5/5.40/site_perl     \
                 -Dvendorlib=/usr/lib/perl5/5.40/vendor_perl  \
                 -Dvendorarch=/usr/lib/perl5/5.40/vendor_perl
    make -j$(nproc)
    make install
}

# ID: python_temp
python_temp() {
    ./configure --prefix=/usr   \
                --enable-shared \
                --without-ensurepip
    make -j$(nproc)
    make install
}

# ID: texinfo_temp
texinfo_temp() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: utillinux_temp
utillinux_temp() {
    mkdir -pv /var/lib/hwclock
    ./configure --libdir=/usr/lib     \
                --runstatedir=/run    \
                --disable-chfn-chsh   \
                --disable-login       \
                --disable-nologin     \
                --disable-su          \
                --disable-setpriv     \
                --disable-runuser     \
                --disable-pylibmount  \
                --disable-static      \
                --without-python      \
                --without-systemd     \
                --without-systemdsystemunitdir \
		--disable-makeinstall-chown \
                --disable-liblastlog2
    make -j$(nproc)
    make install
}

# ID: manpages
manpages() {
    rm -f -v src/ln
    make -R prefix=/usr install
}

# ID: ianaetc
ianaetc() {
    cp services protocols /etc
}

# ID: glibc_final
glibc_final() {
    aplicar_patch "glibc-2.41-fhs-1.patch"

    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    echo "Configuring Glibc (Final)..."
    echo "rootsbindir=/usr/sbin" > configparms

    ../configure --prefix=/usr                            \
                 --disable-werror                         \
                 --enable-kernel=4.19                     \
                 --enable-stack-protector=strong          \
                 --disable-nscd                           \
                 libc_cv_slibdir=/usr/lib

    make -j$(nproc)

    touch /etc/ld.so.conf
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

    make -j$(nproc) install

    echo "   [Recipe] Generating Locales..."
    #make -j1 localedata/install-locales
    #localedef -i C -f UTF-8 C.UTF-8
    #localedef -i en_US -f ISO-8859-1 en_US
    #localedef -i en_US -f UTF-8 en_US.UTF-8
    #localedef -i es_ES -f UTF-8 es_ES.UTF-8
    #Lista nao compila. modificado para:
    mkdir -pv /usr/lib/locale
    localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
    localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
    localedef -i de_DE -f ISO-8859-1 de_DE
    localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
    localedef -i de_DE -f UTF-8 de_DE.UTF-8
    localedef -i el_GR -f ISO-8859-7 el_GR
    localedef -i en_GB -f ISO-8859-1 en_GB
    localedef -i en_GB -f UTF-8 en_GB.UTF-8
    localedef -i en_HK -f ISO-8859-1 en_HK
    localedef -i en_PH -f ISO-8859-1 en_PH
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
    localedef -i es_ES -f ISO-8859-15 es_ES@euro
    localedef -i es_MX -f ISO-8859-1 es_MX
    localedef -i fa_IR -f UTF-8 fa_IR
    localedef -i fr_FR -f ISO-8859-1 fr_FR
    localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
    localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
    localedef -i is_IS -f ISO-8859-1 is_IS
    localedef -i is_IS -f UTF-8 is_IS.UTF-8
    localedef -i it_IT -f ISO-8859-1 it_IT
    localedef -i it_IT -f ISO-8859-15 it_IT@euro
    localedef -i it_IT -f UTF-8 it_IT.UTF-8
    localedef -i ja_JP -f EUC-JP ja_JP
    localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true
    localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
    localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
    localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
    localedef -i se_NO -f UTF-8 se_NO.UTF-8
    localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
    localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
    localedef -i zh_CN -f GB18030 zh_CN.GB18030
    localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
    localedef -i zh_TW -f UTF-8 zh_TW.UTF-8
    localedef -i pt_BR -f UTF-8 pt_BR.UTF-8


    # Configure generic nsswitch
    cat > /etc/nsswitch.conf << "EOF"
passwd: files systemd
group: files systemd
shadow: files systemd
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
EOF

    ln -sfv /usr/share/zoneinfo/Europe/Madrid /etc/localtime

    cat > /etc/ld.so.conf << "EOF"
/usr/local/lib
/opt/lib
include /etc/ld.so.conf.d/*.conf
EOF
    mkdir -pv /etc/ld.so.conf.d
}

# ID: zlib
zlib() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
    rm -fv /usr/lib/libz.a
}

# ID: bzip2
bzip2() {
    aplicar_patch "bzip2-1.0.8-install_docs-1.patch"

    # Ensure symbolic links are relative
    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

    make -f Makefile-libbz2_so
    make clean
    make -j$(nproc)
    make PREFIX=/usr install

    cp -av libbz2.so.* /usr/lib
    ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
    rm -fv /usr/lib/libbz2.a
}

# ID: xz_final
xz_final() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/xz-5.6.1
    make -j$(nproc)
    make install
}

# ID: zstd
zstd() {
    make -j$(nproc) prefix=/usr
    make prefix=/usr install
    rm -v /usr/lib/libzstd.a
}

# ID: lz4
lz4() {
    make -j$(nproc) BUILD_STATIC=no PREFIX=/usr
    make BUILD_STATIC=no PREFIX=/usr install
}

# ID: libxcrypt
libxcrypt() {
    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    ../configure --prefix=/usr                \
                 --disable-static             \
                 --enable-hashes=strong,glibc \
                 --enable-obsolete-api=no     \
                 --disable-failure-tokens

    make -j$(nproc)
    make install
}

# ID: mandb
mandb() {
    ./configure --prefix=/usr                        \
                --docdir=/usr/share/doc/man-db-2.13.0 \
                --sysconfdir=/etc                    \
                --disable-setuid                     \
                --enable-cache-owner=bin             \
                --with-browser=/usr/bin/lynx         \
                --with-vgrind=/usr/bin/vgrind        \
                --with-grap=/usr/bin/grap            \
                --with-systemdtmpfilesdir=/usr/lib/tmpfiles.d

    make -j$(nproc)
    make install

    rm -rf /usr/share/man/{da,de,fi,fr,hu,id,it,ja,ko,nl,pl,ro,ru,sr,sv,tr,zh_CN,zh_TW}
}

# ID: file_final
file_final() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: readline
readline() {
    sed -i '/MV.*old/d' Makefile.in
    sed -i '/{OLDSUFF}/c:' support/shlib-install

    ./configure --prefix=/usr    \
                --disable-static \
                --with-curses    \
                --docdir=/usr/share/doc/readline-8.2.13

    make -j$(nproc) SHLIB_LIBS="-lncursesw"
    make SHLIB_LIBS="-lncursesw" install
}

# ID: m4_final
m4_final() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: bc
bc() {
    CC=gcc ./configure --prefix=/usr -G -O3 -r
    make -j$(nproc)
    make install
}

# ID: flex
flex() {
    ./configure --prefix=/usr \
                --docdir=/usr/share/doc/flex-2.6.4 \
                --disable-static
    make -j$(nproc)
    make install
    ln -sfv flex /usr/bin/lex
}

# ID: tcl
tcl() {
    cd unix
    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --disable-rpath
    make -j$(nproc)

    sed -e "s|$PWD/unix|/usr/lib|" \
        -e "s|$PWD|/usr/include|"  \
        -i tclConfig.sh

    make install
    make install-private-headers
    ln -sfv tclsh8.6 /usr/bin/tclsh
}

# ID: expect
expect() {
    aplicar_patch "expect-5.45.4-gcc14-1.patch"
    ./configure --prefix=/usr           \
                --with-tcl=/usr/lib     \
                --enable-shared         \
                --mandir=/usr/share/man \
                --with-tclinclude=/usr/include
    make -j$(nproc)
    make install
    ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
}

# ID: dejagnu
dejagnu() {
    mkdir -v build
    cd build
    ../configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: binutils_final
binutils_final() {
    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    ../configure --prefix=/usr       \
                 --sysconfdir=/etc   \
                 --enable-gold       \
                 --enable-ld=default \
                 --enable-plugins    \
                 --enable-shared     \
                 --disable-werror    \
                 --enable-64-bit-bfd \
                 --with-system-zlib  \
                 --enable-default-hash-style=gnu

    make -j$(nproc) tooldir=/usr
    make tooldir=/usr install
    rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a
}

# ID: gmp
gmp() {
    ./configure --prefix=/usr    \
                --enable-cxx     \
                --disable-static \
                --docdir=/usr/share/doc/gmp-6.3.0
    make -j$(nproc)
    make install
}

# ID: mpfr
mpfr() {
    ./configure --prefix=/usr        \
                --disable-static     \
                --enable-thread-safe \
                --docdir=/usr/share/doc/mpfr-4.2.1
    make -j$(nproc)
    make install
}

# ID: mpc
mpc() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/mpc-1.3.1
    make -j$(nproc)
    make install
}

# ID: attr
attr() {
    ./configure --prefix=/usr     \
                --disable-static  \
                --sysconfdir=/etc \
                --docdir=/usr/share/doc/attr-2.5.2
    make -j$(nproc)
    make install
}

# ID: acl
acl() {
    ./configure --prefix=/usr         \
                --disable-static      \
                --docdir=/usr/share/doc/acl-2.3.2
    make -j$(nproc)
    make install
}

# ID: libcap
libcap() {
    sed -i '/install.*STALIBNAME/d' libcap/Makefile
    make -j$(nproc) prefix=/usr lib=lib
    make prefix=/usr lib=lib install
}

# ID: shadow
shadow() {
    sed -i 's/groups$(EXEEXT) //' src/Makefile.in
    find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;

    sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
        -e 's:/var/spool/mail:/var/mail:'                 \
        -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                \
        -i etc/login.defs

    touch /usr/bin/passwd
    ./configure --sysconfdir=/etc   \
                --disable-static    \
                --with-group-name-max-length=32 \
		--without-libbsd

    make -j$(nproc)
    make exec_prefix=/usr install
    make -C man install-man

    # Set root password to 'root' automatically so user is not locked out
    echo "root:root" | chpasswd
    echo "   [Recipe] WARNING: Root password set to 'root'. Change it later!"

    pwconv
    grpconv
}

# ID: gcc_final
gcc_final() {
    echo "   [Recipe] Unpacking GCC dependencies (gmp, mpfr, mpc)..."
    tar -xf ../mpfr-*.tar.xz
    mv -v mpfr-* mpfr
    tar -xf ../gmp-*.tar.xz
    mv -v gmp-* gmp
    tar -xf ../mpc-*.tar.gz
    mv -v mpc-* mpc

    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
      ;;
    esac

    local pasta_build="build"
    mkdir -v "$pasta_build"
    cd "$pasta_build"

    echo "   [Recipe] Configuring GCC Final..."
    ../configure --prefix=/usr            \
                 LD=ld                    \
                 --enable-languages=c,c++ \
                 --enable-default-pie     \
                 --enable-default-ssp     \
                 --disable-multilib       \
                 --disable-bootstrap      \
                 --disable-fixincludes    \
                 --with-system-zlib

    make -j$(nproc)
    make install

    ln -svrf /usr/bin/cpp /usr/lib
    ln -svf gcc /usr/bin/cc
    ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/14.2.0/liblto_plugin.so \
            /usr/lib/bfd-plugins/

    # 7. Teste de Sanidade (Sanity Check)
    echo "   [Recipe] Running final compiler sanity check..."
    echo 'int main(){}' > dummy.c
    cc dummy.c -v -Wl,--verbose &> dummy.log

    # Verifica se o linker usado é o ld-linux correto
    if ! grep -q '/usr/lib/ld-linux-x86-64.so.2' dummy.log; then
        echo "CRITICAL ERROR: Compiler not linking against correct loader."
        echo "Check dummy.log for details."
        # Em script de automação, talvez queira um 'exit 1' aqui
    else
        echo "   [Recipe] Sanity Check PASSED."
    fi

    rm -v dummy.c dummy.log a.out
}

# ID: pkgconf
pkgconf() {
    ./configure --prefix=/usr              \
                --disable-static           \
                --docdir=/usr/share/doc/pkgconf-2.3.0
    make -j$(nproc)
    make install
    ln -svf pkgconf /usr/bin/pkg-config
}

# ID: ncurses_final
ncurses_final() {
    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --with-shared           \
                --without-debug         \
                --without-normal        \
                --with-cxx-shared       \
                --enable-pc-files       \
                --enable-widec          \
                --with-pkg-config-libdir=/usr/lib/pkgconfig

    make -j$(nproc)
    make install

    # Create compatibility symlinks (libncurses -> libncursesw)
    for lib in ncurses form panel menu ; do
        rm -vf                    /usr/lib/lib${lib}.so
        echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
        ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
    done

    rm -vf                     /usr/lib/libcursesw.so
    echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
    ln -sfv libncurses.so      /usr/lib/libcurses.so
}

# ID: sed_final
sed_final() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: psmisc
psmisc() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: gettext
gettext() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/gettext-0.24
    make -j$(nproc)
    make install
    chmod -v 0755 /usr/lib/preloadable_libintl.so
}

# ID: bison
bison() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
    make -j$(nproc)
    make install
}

# ID: grep_final
grep_final() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: bash_final
bash_final() {
    ./configure --prefix=/usr             \
                --without-bash-malloc     \
                --with-installed-readline \
                --docdir=/usr/share/doc/bash-5.2.37
    make -j$(nproc)
    make install
}

# ID: libtool
libtool() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
    rm -fv /usr/lib/libltdl.a
}

# ID: gdbm
gdbm() {
    ./configure --prefix=/usr    \
                --disable-static \
                --enable-libgdbm-compat
    make -j$(nproc)
    make install
}

# ID: gperf
gperf() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
    make -j$(nproc)
    make install
}

# ID: expat
expat() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/expat-2.6.4
    make -j$(nproc)
    make install
}

# ID: inetutils
inetutils() {
    CFLAGS="-Wno-implicit-function-declaration" ./configure --prefix=/usr        \
                --bindir=/usr/bin    \
                --localstatedir=/var \
                --disable-logger     \
                --disable-whois      \
                --disable-rcp        \
                --disable-rexec      \
                --disable-rlogin     \
                --disable-rsh        \
                --disable-servers
    make -j$(nproc)
    make install
    mv -v /usr/{,s}bin/ifconfig
}

# ID: less
less() {
    ./configure --prefix=/usr --sysconfdir=/etc
    make -j$(nproc)
    make install
}

# ID: perl
perl() {
    export BUILD_ZLIB=False
    export BUILD_BZIP2=0

    sh Configure -des                                         \
                 -Dprefix=/usr                                \
                 -Dvendorprefix=/usr                          \
                 -Dprivlib=/usr/lib/perl5/5.40/core_perl      \
                 -Darchlib=/usr/lib/perl5/5.40/core_perl      \
                 -Dsitelib=/usr/lib/perl5/5.40/site_perl      \
                 -Dsitearch=/usr/lib/perl5/5.40/site_perl     \
                 -Dvendorlib=/usr/lib/perl5/5.40/vendor_perl  \
                 -Dvendorarch=/usr/lib/perl5/5.40/vendor_perl \
                 -Dman1dir=/usr/share/man/man1                \
                 -Dman3dir=/usr/share/man/man3                \
                 -Dpager="/usr/bin/less -isR"                 \
                 -Duseshrplib                                 \
                 -Dusethreads

    make -j$(nproc)
    make install

    unset BUILD_ZLIB BUILD_BZIP2
}

# ID: xmlparser
xmlparser() {
    /usr/bin/perl Makefile.PL
    make -j$(nproc)
    make install
}

# ID: intltool
intltool() {
    sed -i 's:\\\${:\\\$\\{:' intltool-update.in
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: autoconf
autoconf() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: automake
automake() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.17
    make -j$(nproc)
    make install
}

# ID: openssl
openssl() {
    ./config --prefix=/usr         \
             --openssldir=/etc/ssl \
             --libdir=lib          \
             shared                \
             zlib-dynamic

    make -j$(nproc)
    make install
    rm -f /usr/lib/libcrypto.a /usr/lib/libssl.a
}

# ID: libelf
# ID: libelf
libelf() {
    ./configure --prefix=/usr                \
                --disable-debuginfod         \
                --enable-libdebuginfod=dummy

    make -j$(nproc)
    make -C libelf install

    install -vm644 config/libelf.pc /usr/lib/pkgconfig
    rm -f /usr/lib/libelf.a
}

# ID: libffi
libffi() {
    ./configure --prefix=/usr          \
                --disable-static       \
                --with-gcc-arch=native
    make -j$(nproc)
    make install
}

# ID: python
python() {
    ./configure --prefix=/usr        \
                --enable-shared      \
                --with-system-expat  \
                --enable-optimizations
    make -j$(nproc)
    make install

    cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF
}

# ID: flitcore
flitcore() {
    pip3 wheel -w dist --no-build-isolation --no-deps $PWD
    pip3 install --no-index --no-user --find-links dist flit_core
}

# ID: wheel
wheel() {
    pip3 wheel -w dist --no-build-isolation --no-deps $PWD
    pip3 install --no-index --no-user --find-links dist wheel
}

# ID: setuptools
setuptools() {
    pip3 wheel -w dist --no-build-isolation --no-deps $PWD
    pip3 install --no-index --no-user --find-links dist setuptools
}

# ID: markupsafe
markupsafe() {
    pip3 wheel -w dist --no-build-isolation --no-deps $PWD
    pip3 install --no-index --no-user --find-links dist MarkupSafe
}

# ID: jinja2
jinja2() {
    pip3 wheel -w dist --no-build-isolation --no-deps $PWD
    pip3 install --no-index --no-user --find-links dist Jinja2
}

# ID: ninja
ninja() {
    python3 configure.py --bootstrap
    install -vm755 ninja /usr/bin/
    install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
}

# ID: meson
meson() {
    pip3 wheel -w dist --no-build-isolation --no-deps $PWD
    pip3 install --no-index --no-user --find-links dist meson
    install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
}

# ID: kmod
kmod() {
    mkdir -p build
    cd build

    command meson setup --prefix=/usr .. \
                --sbindir=/usr/sbin \
                --buildtype=release \
                -D manpages=false

    command ninja -j$(nproc)
    command ninja install
}

# ID: coreutils_final
coreutils_final() {
    #aplicar_patch "coreutils-9.6-i18n-1.patch"

    export FORCE_UNSAFE_CONFIGURE=1

    ./configure --prefix=/usr                     \
                --enable-install-program=hostname \
                --enable-no-install-program=kill,uptime

    make ACLOCAL=true AUTOMAKE=true AUTOCONF=true MAKEINFO=true -j$(nproc)
    make install

    mv -v /usr/bin/chroot /usr/sbin
    mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
}

# ID: check
check() {
    ./configure --prefix=/usr --disable-static
    make -j$(nproc)
    make install
}

# ID: diffutils_final
diffutils_final() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: gawk_final
gawk_final() {
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: findutils_final
findutils_final() {
    ./configure --prefix=/usr --localstatedir=/var/lib/locate
    make -j$(nproc)
    make install
}

# ID: groff
groff() {
    PAGE=A4 ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: grub
grub() {
    unset {C,CPP,CXX,LD}FLAGS

    echo depends bli part_gpt > grub-core/extra_deps.lst

    ./configure --prefix=/usr          \
                --sysconfdir=/etc      \
                --disable-efiemu       \
                --disable-werror

    make -j$(nproc)
    make install

    mkdir -p /usr/share/bash-completion/completions
    mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions/grub
}

# ID: gzip_final
gzip_final() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: iproute2
iproute2() {
    sed -i /ARPD/d Makefile
    rm -fv man/man8/arpd.8
    make NETNS_RUN_DIR=/run/netns
    make SBINDIR=/usr/sbin install
}

# ID: kbd
kbd() {
    aplicar_patch "kbd-2.7.1-backspace-1.patch"
    sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
    sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

    ./configure --prefix=/usr --disable-vlock
    make -j$(nproc)
    make install
}

# ID: libpipeline
libpipeline() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: make_final
make_final() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: patch_final
patch_final() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: tar_final
tar_final() {
    FORCE_UNSAFE_CONFIGURE=1  \
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: texinfo
texinfo() {
    ./configure --prefix=/usr
    make -j$(nproc)
    make install
}

# ID: vim
vim() {
    echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
    ./configure --prefix=/usr
    make -j$(nproc)
    make install

    # Simple vimrc configuration
    cat > /etc/vimrc << "EOF"
set nocompatible
set backspace=2
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif
EOF
}

# ID: nano
nano() {
    ./configure --prefix=/usr     \
                --sysconfdir=/etc \
                --enable-utf8     \
                --docdir=/usr/share/doc/nano-8.7

    make -j$(nproc)
    make install

    install -v -m644 doc/sample.nanorc /etc/nanorc
    #Cor no texto
    sed -i '/include "\/usr\/share\/nano\/\*\.nanorc"/s/^# //' /etc/nanorc
}

# ID: utillinux
utillinux() {
    ./configure --bindir=/usr/bin     \
                --libdir=/usr/lib     \
                --runstatedir=/run    \
                --sbindir=/usr/sbin   \
                --disable-chfn-chsh   \
                --disable-login       \
                --disable-nologin     \
                --disable-su          \
                --disable-setpriv     \
                --disable-runuser     \
                --disable-pylibmount  \
                --disable-static      \
                --without-python      \
                --without-systemd     \
                --without-systemdsystemunitdir \
                --disable-liblastlog2

    make -j$(nproc)
    make install
}

# ID: e2fsprogs
e2fsprogs() {
    mkdir -v build
    cd build

    ../configure --prefix=/usr           \
                 --sysconfdir=/etc       \
                 --enable-elf-shlibs     \
                 --disable-libblkid      \
                 --disable-libuuid       \
                 --disable-uuidd         \
                 --disable-fsck

    make -j$(nproc)
    make install

    rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
}

# ID: systemd
systemd() {
    sed -i -e 's/GROUP="render"/GROUP="video"/' \
           -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in

    mkdir -p build
    cd build

    command meson setup \
      --prefix=/usr                 \
      --buildtype=release           \
      -Ddefault-dnssec=no           \
      -Dfirstboot=false             \
      -Dinstall-tests=false         \
      -Dldconfig=false              \
      -Dsysusers=false              \
      -Drpmmacrosdir=no             \
      -Dhomed=false                 \
      -Duserdb=false                \
      -Dman=false                   \
      -Dmode=release                \
      -Dpamconfdir=no               \
      -Ddev-kvm-mode=0660           \
      -Dnobody-group=nogroup        \
      -Dsysupdate=false             \
      -Dukify=false                 \
      -Ddocdir=/usr/share/doc/systemd-257.3 \
      ..

    command ninja
    command ninja install

    systemd-machine-id-setup

    systemctl preset-all
}

# ID: dbus
dbus() {
    mkdir -p build
    cd build

    command meson setup --prefix=/usr \
                        --buildtype=release \
                        --wrap-mode=nofallback \
                        ..

    command ninja -j$(nproc)
    command ninja install

    ln -sfv /etc/machine-id /var/lib/dbus/machine-id
}

# ID: procpsng
procpsng() {
    ./configure --prefix=/usr                            \
                --docdir=/usr/share/doc/procps-ng-4.0.5  \
                --disable-static                         \
                --disable-kill
    make -j$(nproc)
    make install
}

# ==================================================================
# FASE 3: Compiling Final Kernel
# ==================================================================

# ID: linux_kernel
linux_kernel() {
    echo "   [Recipe] Cleaning kernel tree..."
    make mrproper

    echo "   [Recipe] Configuring Kernel (Using defconfig)..."
    # Ideally, you should run 'make menuconfig' manually later if needed.
    make defconfig

    #Enabeling Disk's Modules as Built-in (for Grub)
    sed -i 's/CONFIG_EXT4_FS=m/CONFIG_EXT4_FS=y/' .config
    sed -i 's/# CONFIG_EXT4_FS is not set/CONFIG_EXT4_FS=y/' .config
    sed -i 's/CONFIG_BLK_DEV_NVME=m/CONFIG_BLK_DEV_NVME=y/' .config
    sed -i 's/# CONFIG_BLK_DEV_NVME is not set/CONFIG_BLK_DEV_NVME=y/' .config
    sed -i 's/CONFIG_SATA_AHCI=m/CONFIG_SATA_AHCI=y/' .config
    sed -i 's/# CONFIG_SATA_AHCI is not set/CONFIG_SATA_AHCI=y/' .config

    echo "   [Recipe] Compiling Kernel Image and Modules..."
    make -j$(nproc)

    echo "   [Recipe] Installing Modules..."
    make modules_install

    KVER=$(make -s kernelrelease)
    echo "   [Recipe] Detected Kernel Version: $KVER"

    echo "   [Recipe] Installing Kernel Image..."
    cp -iv arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}-lfs"
    cp -iv System.map "/boot/System.map-${KVER}"
    cp -iv .config "/boot/config-${KVER}"

    echo "   [Recipe] Kernel $KVER installed successfully!"
}

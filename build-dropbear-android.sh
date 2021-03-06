#!/bin/bash

set -e

if [ -z $ANDROID_NDK_HOME ]; then
        echo "ANDROID_NDK_HOME is empty.";
		exit -1;
else
        echo ANDROID_NDK_HOME=${ANDROID_NDK_HOME}
fi

#if [ -z ${TOOLCHAIN} ]; then echo "TOOLCHAIN must be set. See README.md for more information."; exit -1; fi

# Setup the environment
export TARGET=../target
# Specify binaries to build. Options: dropbear dropbearkey scp dbclient
export PROGRAMS="dropbearconvert dropbearkey dbclient"
# Which version of Dropbear to download for patching
export VERSION=2015.67

# Download the latest version of dropbear SSH
if [ ! -f ./dropbear-$VERSION.tar.bz2 ]; then
    wget -O ./dropbear-$VERSION.tar.bz2 https://matt.ucc.asn.au/dropbear/releases/dropbear-$VERSION.tar.bz2
fi

# Start each build with a fresh source copy
rm -rf ./dropbear-$VERSION
tar xjf dropbear-$VERSION.tar.bz2

# Change to dropbear directory
cd dropbear-$VERSION

### START -- configure without modifications first to generate files 
#########################################################################################################################
echo "Generating required files..."

API=16
GCC=4.9

# API < 21
HOST=(arm-linux-androideabi x86 mipsel-linux-android)
ARCH=(arm x86 mips)
PREFIX=(arm-linux-androideabi- x86- mipsel-linux-android-)
CCPREFIX=(arm-linux-androideabi- i686-linux-android- mipsel-linux-android-)

# API > 21
#HOST=(aarch64-linux-android arm-linux-androideabi x86 mipsel-linux-android)
#ARCH=(aarch64 arm x86 mips)
#PREFIX=(aarch64-linux-android- arm-linux-androideabi- x86- mipsel-linux-android-)
#CCPREFIX=(aarch64-linux-android- arm-linux-androideabi- i686-linux-android- mipsel-linux-android-)

# Android 5.0 Lollipop and greater require PIE. Default to this unless otherwise specified.
#if [ -z $DISABLE_PIE ]; then export CFLAGS="-g -O2 -pie -fPIE"; LDFLAGS="-g -O2 -pie -fPIE"; else echo "Disabling PIE compilation..."; fi
sleep 5
# Use the default platform target for pie binaries 
unset GOOGLE_PLATFORM

# Apply the new config.guess and config.sub now so they're not patched
cp ../config.guess ../config.sub .
    
#echo "./configure --host=$HOST --disable-utmp --disable-wtmp --disable-utmpx --disable-zlib --disable-syslog > /dev/null 2>&1"
#./configure --host=$HOST --disable-utmp --disable-wtmp --disable-utmpx --disable-zlib --disable-syslog

echo "Done generating files"
sleep 2
echo
echo
#########################################################################################################################
### END -- configure without modifications first to generate files 

# Begin applying changes to make Android compatible
# Apply the compatibility patch
patch -p1 < ../android-$VERSION.patch
cd -


for I in $(seq 0 $((${#ARCH[@]} - 1))); do
	TOOLCHAIN=${ANDROID_NDK_HOME}/toolchains/${PREFIX[$I]}${GCC}/prebuilt/linux-x86_64
	COMPILER=${TOOLCHAIN}/bin/${CCPREFIX[$I]}gcc
	STRIP=${TOOLCHAIN}/bin/${CCPREFIX[$I]}strip
	SYSPREFIX="${ANDROID_NDK_HOME}/platforms/android-${API}/arch-"
	SYSROOT="${SYSPREFIX}${ARCH[$I]}"
	export CC="$COMPILER --sysroot=$SYSROOT -g -O2 -pie -fPIE"

	mkdir -p build-${ARCH[$I]}
	cd build-${ARCH[$I]}
	echo "Compiling for ${ARCH[$I]}" > build-${ARCH[$I]}.log 2>&1
	../dropbear-$VERSION/configure --host=${HOST[$I]} --disable-utmp --disable-wtmp --disable-utmpx --disable-zlib --disable-syslog >> build-${ARCH[$I]}.log 2>&1

	make PROGRAMS="$PROGRAMS" >> build-${ARCH[$I]}.log 2>&1
	MAKE_SUCCESS=$?
	if [ $MAKE_SUCCESS -eq 0 ]; then
		echo "Built for ${ARCH[$I]} successfully!"
		sleep 1
		# Create the output directory
		mkdir -p bin;
		for PROGRAM in $PROGRAMS; do

			if [ ! -f $PROGRAM ]; then
				echo "${PROGRAM} not found!"
			fi

			$STRIP "./${PROGRAM}"
		done

		cp $PROGRAMS bin
		echo "Compilation successful. Output files are located in: build-${ARCH[$I]}/bin" >> build-${ARCH[$I]}.log 2>&1
	else
		echo "Compilation failed."
	fi
	cd ..
done



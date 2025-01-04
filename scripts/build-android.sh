#!/bin/bash

# SPDX-License-Identifier: MIT

set -e

show_help() {
    echo ""
    echo " Usage: ./build-android <ndk-dir> -a [abi] -b [build-directory] -s [sdk-version] -p [platform-version] -m [mechanisms]"

    echo "   ndk-dir: the directory of the Android NDK (required)"
    echo "   abi: the Android ABI to target for the build"
    echo "   build-directory: the directory in which to build the project"
    echo "   sdk-version: the minimum Android SDK version to target"
    echo "   platform-version: -DANDROID_PLATFORM"
    echo "   mechanisms: -DOQS_MINIMAL_BUILD"
    echo ""
    exit 0
}

# If no arguments provided, show help
if [ $# -eq 0 ]
then
    show_help
fi

# If help requested, show help
for arg in "$@"
do
    if [ "$arg" == "--help" ] || [ "$arg" == "-h" ]
    then
        show_help
    fi
done

# Make sure script will work the same if called from
# root directory or scripts directory
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path/.."

NDK=$1
# Verify NDK is valid directory
if [ -d "$NDK" ]
then
    echo "Valid directory for NDK at $NDK"
else
    echo "Directory for NDK doesn't exist at $NDK"
    exit 1
fi

# Parse optional parameters
ABI="armeabi-v7a"
MINSDKVERSION=25
BUILDDIR="build"
PLATFORM="android-25"
MINBUILD="KEM_kyber_1024;"

OPTIND=2
while getopts "a:s:b:p:m:" flag
do
    case $flag in
        a) ABI=$OPTARG;;
        s) MINSDKVERSION=$OPTARG;;
        b) BUILDDIR=$OPTARG;;
        p) PLATFORM=$OPTARG;;
        m) MINBUILD=$OPTARG;;
        *) exit 1
    esac
done

# Check ABI is supported
valid_abis=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")
abi_match=false
for i in "${valid_abis[@]}"
do
   :
   if [ "$ABI" == "$i" ]
   then abi_match=true
   fi
done
if [ "$abi_match" = true ]
then
    echo "Compiling for ABI $ABI"
else
    echo "Invalid Android ABI of $ABI"
    echo "Valid ABIs are:"
    printf "%s\\n" "${valid_abis[@]}"
    exit 1
fi

# Check SDK version is supported
highestSdkVersion=29
if (( 1 <= MINSDKVERSION && MINSDKVERSION <= highestSdkVersion ))
then
    echo "Compiling for SDK $MINSDKVERSION"
else
    echo "Invalid SDK level of $MINSDKVERSION"
    exit 1
fi

# Remove build directory if it exists
if [ -d "$BUILDDIR" ]
then
    echo "Cleaning up previous build"
    rm -r "$BUILDDIR"
fi

echo "Building in directory $BUILDDIR"

# Build
mkdir "$BUILDDIR" && cd "$BUILDDIR"
cmake .. -DOQS_USE_OPENSSL=OFF \
         -DANDROID_ABI="$ABI" \
         -DANDROID_PLATFORM="$PLATFORM" \
         -DCMAKE_BUILD_TYPE=Release \
         -DBUILD_SHARED_LIBS=ON \
         -DOQS_DIST_BUILD=ON \
         -DOQS_MINIMAL_BUILD="$MINBUILD"  \
         -DOQS_BUILD_ONLY_LIB=ON   \
         -DCMAKE_TOOLCHAIN_FILE="$NDK"/build/cmake/android.toolchain.cmake \
         -DANDROID_NATIVE_API_LEVEL="$MINSDKVERSION"
cmake --build ./

# Copy built library to jniLibs directory
echo "Copy built library to jniLibs directory"
lib_file="../build/lib/liboqs.so"
dest_dir="../../jniLibs/$ABI"
if [ -f "$lib_file" ]; then
    mkdir -p $dest_dir
    chmod -R 755 $dest_dir
    cp -f $lib_file $dest_dir
    # echo "$lib_file copied to jniLibs/$ABI"
fi

# Provide rudimentary information following build
# echo "Completed build run for ABI $ABI, SDK Version $MINSDKVERSION"

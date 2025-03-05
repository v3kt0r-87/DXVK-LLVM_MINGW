#!/usr/bin/env bash

set -e

shopt -s extglob

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 version destdir [--no-package] [--dev-build]"
  exit 1
fi

install_llvm_mingw() {

   sudo apt install glslang-tools  glslang-dev -y

    # LLVM MinGW Setup
    LLVM_MINGW_URL="https://github.com/v3kt0r-87/Clang-Stable/releases/download/llvm-mingw-20.0.1.0-RC3/llvm-mingw.zip"
    LLVM_MINGW_PATH="$(pwd)/llvm-mingw"

    echo "Checking for LLVM MinGW..."

    if [ ! -d "$LLVM_MINGW_PATH" ]; then

        echo "LLVM MinGW not found! Downloading..."

        wget -O llvm-mingw.zip "$LLVM_MINGW_URL"

        unzip llvm-mingw.zip -d "$LLVM_MINGW_PATH"
        rm llvm-mingw.zip

        echo "LLVM MinGW installed successfully!"

    else
        echo "LLVM MinGW is already installed."
    fi

    export PATH="$(pwd)/llvm-mingw/bin:$PATH"
}

install_llvm_mingw

DXVK_VERSION="$1"
DXVK_SRC_DIR=$(readlink -f "$0")
DXVK_SRC_DIR=$(dirname "$DXVK_SRC_DIR")
DXVK_BUILD_DIR=$(realpath "$2")"/dxvk-native-$DXVK_VERSION"
DXVK_ARCHIVE_PATH=$(realpath "$2")"/dxvk-native-$DXVK_VERSION.tar.gz"

if [ -e "$DXVK_BUILD_DIR" ]; then
  echo "Build directory $DXVK_BUILD_DIR already exists"
  exit 1
fi

shift 2

opt_nopackage=0
opt_devbuild=0
opt_buildid=false
opt_64_only=0
opt_32_only=0

CC=${CC:="clang"}
CXX=${CXX:="clang++"}

export LDFLAGS="-fuse-ld=lld"

while [ $# -gt 0 ]; do
  case "$1" in
  "--no-package")
    opt_nopackage=1
    ;;
  "--dev-build")
    opt_nopackage=1
    opt_devbuild=1
    ;;
  "--build-id")
    opt_buildid=true
    ;;
  "--64-only")
    opt_64_only=1
    ;;
  "--32-only")
    opt_32_only=1
    ;;
  *)
    echo "Unrecognized option: $1" >&2
    exit 1
  esac
  shift
done

function build_arch {  
  cd "$DXVK_SRC_DIR"

  opt_strip=
  if [ $opt_devbuild -eq 0 ]; then
    opt_strip=--strip
  fi

  CC="$CC" CXX="$CXX" meson setup  \
        --buildtype "release"                \
        --prefix "$DXVK_BUILD_DIR/usr"       \
        $opt_strip                           \
        --bindir "$2"                        \
        --libdir "$2"                        \
        -Dbuild_id=$opt_buildid              \
        --force-fallback-for=libdisplay-info \
        -Db_lto=true                         \
        "$DXVK_BUILD_DIR/build.$1"

  cd "$DXVK_BUILD_DIR/build.$1"
  ninja install

  if [ $opt_devbuild -eq 0 ]; then
    rm -r "$DXVK_BUILD_DIR/build.$1"
  fi
}

function package {
  cd "$DXVK_BUILD_DIR"
  tar -czf "$DXVK_ARCHIVE_PATH" "usr"
  cd ".."
  rm -R "dxvk-native-$DXVK_VERSION"
}

if [ $opt_32_only -eq 0 ]; then
  build_arch 64 lib
fi
if [ $opt_64_only -eq 0 ]; then
  build_arch 32 lib32
fi

if [ $opt_nopackage -eq 0 ]; then
  package
fi

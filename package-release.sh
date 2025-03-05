#!/usr/bin/env bash

set -e

shopt -s extglob

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

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 version destdir [--no-package] [--dev-build]"
  exit 1
fi

DXVK_VERSION="$1"
DXVK_SRC_DIR=$(readlink -f "$0")
DXVK_SRC_DIR=$(dirname "$DXVK_SRC_DIR")
DXVK_BUILD_DIR=$(realpath "$2")"/dxvk-$DXVK_VERSION"
DXVK_ARCHIVE_PATH=$(realpath "$2")"/dxvk-$DXVK_VERSION.tar.gz"

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

crossfile="build-win"

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
  export WINEARCH="win$1"
  export WINEPREFIX="$DXVK_BUILD_DIR/wine.$1"
  
  cd "$DXVK_SRC_DIR"

  opt_strip=
  if [ $opt_devbuild -eq 0 ]; then
    opt_strip=--strip
  fi

 meson setup --cross-file "$DXVK_SRC_DIR/$crossfile$1.txt" --native-file "native.txt" \
        --buildtype "release"                               \
        --prefix "$DXVK_BUILD_DIR"                          \
        $opt_strip                                          \
        --bindir "x$1"                                      \
        --libdir "x$1"                                      \
        -Db_ndebug=if-release                               \
        -Dbuild_id=$opt_buildid                             \
        -Db_lto=true                                        \
        "$DXVK_BUILD_DIR/build.$1"

  cd "$DXVK_BUILD_DIR/build.$1"
  ninja install

  if [ $opt_devbuild -eq 0 ]; then
    # get rid of some useless .a files
    rm "$DXVK_BUILD_DIR/x$1/"*.!(dll)
    rm -R "$DXVK_BUILD_DIR/build.$1"
  fi
}

function package {
  cd "$DXVK_BUILD_DIR/.."
  tar -czf "$DXVK_ARCHIVE_PATH" "dxvk-$DXVK_VERSION"
  rm -R "dxvk-$DXVK_VERSION"
}

if [ $opt_32_only -eq 0 ]; then
  build_arch 64
fi
if [ $opt_64_only -eq 0 ]; then
  build_arch 32
fi

if [ $opt_nopackage -eq 0 ]; then
  package
fi

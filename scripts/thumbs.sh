#!/bin/bash

# THe Ultimate Make Bash Script
# Used to wrap build scripts for easy dep
# handling and multiplatform support


# Basic usage on *nix:
# export tbs_arch=x86
# ./thumbs.sh make


# On Win (msvc 2013):
# C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall x86_amd64
# SET tbs_tools=msvc12
# thumbs make

# On Win (mingw32):
# SET path=C:\mingw32\bin;%path%
# SET tbs_tools=mingw
# SET tbs_arch=x86
# thumbs make


# Global settings are stored in env vars
# Should be inherited

[ $tbs_conf ]           || export tbs_conf=Release
[ $tbs_arch ]           || export tbs_arch=x64
[ $tbs_tools ]          || export tbs_tools=gnu
[ $tbs_static_runtime ] || export tbs_static_runtime=0


# tbsd_* contains dep related settings
# tbsd_[name]_* contains settings specific to the dep
# name should match the repo name

# deps contains a map of what should be built/used
# keep the keys in sync ... no assoc arrays on msys :/
# targ contains a target for each dep (default=empty str)
# post is executed after each thumbs dep build
# ^ used for copying/renaming any libs you need - uses eval

deps=()
targ=()
post=()

[ $tbsd_zlib_repo ]     || export tbsd_zlib_repo="https://github.com/imazen/zlib --branch for-upstream-use --single-branch"

zname=zlib.lib
[ $tbs_tools = gnu -o $tbs_tools = mingw ] && zname=libz.a

deps+=(zlib)
targ+=(zlibstatic)
post+=("cp -u \$(./thumbs.sh list_slib) ../../deps/$zname")

# -----------
# dep processor

process_deps()
{
  mkdir build_deps
  mkdir deps
  cd build_deps

  for key in "${!deps[@]}"
  do
    dep=${deps[$key]}
    i_dep_repo="tbsd_${dep}_repo"
    i_dep_incdir="tbsd_${dep}_incdir"
    i_dep_libdir="tbsd_${dep}_libdir"
    i_dep_built="tbsd_${dep}_built"
    
    [ ${!i_dep_built} ] || export "${i_dep_built}=0"
    
    if [ ${!i_dep_built} -eq 0 ]
    then
      git clone ${!i_dep_repo} --depth 1
      cd $dep || exit 1
      ./thumbs.sh make ${targ[$key]} || exit 1
      
      # copy any includes and do poststep
      cp -u $(./thumbs.sh list_inc) ../../deps
      eval ${post[$key]}
      
      # look in both local and parent dep dirs
      export "${i_dep_incdir}=../../deps;deps"
      export "${i_dep_libdir}=../../deps;deps"
      export "${i_dep_built}=1"
      
      cd ..
    fi
  done
  
  cd ..
}

# -----------
# constructs dep dirs for cmake

postproc_deps()
{
  cm_inc=
  cm_lib=
  
  for dep in "${deps[@]}"
  do
    i_dep_incdir="tbsd_${dep}_incdir"
    i_dep_libdir="tbsd_${dep}_libdir"
    
    cm_inc="${!i_dep_incdir};$cm_inc"
    cm_lib="${!i_dep_libdir};$cm_lib"
  done
  
  cm_args+=(-DCMAKE_LIBRARY_PATH=$cm_lib)
  cm_args+=(-DCMAKE_INCLUDE_PATH=$cm_inc)
}

# -----------

if [ $# -lt 1 ]
then
  echo ""
  echo " Usage : ./thumbs.sh [command]"
  echo ""
  echo " Commands:"
  echo "   make [target]   - builds everything"
  echo "   check           - runs tests"
  echo "   check2          - download and run all pngsuite tests"
  echo "                     www.schaik.com/pngsuite/PngSuite-2013jan13.zip"
  echo "   clean           - removes build files"
  echo "   list            - echo paths to any interesting files"
  echo "                     space separated; relative"
  echo "   list_bin        - echo binary paths"
  echo "   list_inc        - echo lib include files"
  echo "   list_slib       - echo static lib path"
  echo "   list_dlib       - echo dynamic lib path"
  echo ""
  exit
fi

# -----------

upper()
{
  echo $1 | tr [:lower:] [:upper:]
}

# Local settings

ver=16
rel=14

l_inc="./png.h ./pngconf.h ./build/pnglibconf.h"
l_slib=
l_dlib=
l_bin=
list=

pngtest=build/pngtest
make=
c_flags=
cm_tools=
cm_args=(-DCMAKE_BUILD_TYPE=$tbs_conf -Wno-dev)

target=
[ $2 ] && target=$2

# -----------

case "$tbs_tools" in
msvc12)
  # d suffix for debug builds
  csx=
  [ "$tbs_conf" = "Debug" ] && csx=d
  
  cm_tools="Visual Studio 12"
  [ "$target" = "" ] && mstrg="libpng.sln" || mstrg="$target.vcxproj"
  make="msbuild.exe $mstrg //p:Configuration=$tbs_conf //v:m"
  pngtest="build/$tbs_conf/pngtest"
  l_slib="./build/$tbs_conf/libpng${ver}_static$csx.lib"
  l_dlib="./build/$tbs_conf/libpng$ver$csx.lib"
  l_bin="./build/$tbs_conf/libpng$ver$csx.dll"
  list="$l_bin $l_slib $l_dlib $l_inc" ;;
gnu)
  cm_tools="Unix Makefiles"
  c_flags+=" -fPIC"
  make="make $target"
  l_slib="./build/libpng.a"
  l_dlib="./build/libpng.so.$ver.$rel.0"
  l_bin="$l_dlib"
  list="$l_slib $l_dlib $l_inc" ;;
mingw)
  cm_tools="MinGW Makefiles"
  make="mingw32-make $target"
  
  # allow sh in path; some old cmake/mingw bug?
  cm_args+=(-DCMAKE_SH=)
  
  l_slib="./build/libpng$ver.a"
  l_dlib="./build/libpng$ver.dll.a"
  l_bin="./build/libpng$ver.dll"
  list="$l_bin $l_slib $l_dlib $l_inc" ;;

*) echo "Tool config not found for $tbs_tools"
   exit 1 ;;
esac

# -----------

case "$tbs_arch" in
x64)
  [ $tbs_tools = msvc12 ] && cm_tools="$cm_tools Win64"
  [ $tbs_tools = gnu -o $tbs_tools = mingw ] && c_flags+=" -m64" ;;
x86)
  [ $tbs_tools = gnu -o $tbs_tools = mingw ] && c_flags+=" -m32" ;;

*) echo "Arch config not found for $tbs_arch"
   exit 1 ;;
esac

# -----------

if [ $tbs_static_runtime -gt 0 ]
then
  [ $tbs_tools = msvc12 ] && c_flags+=" /MT"
  [ $tbs_tools = gnu -o $tbs_tools = mingw ] && cm_args+=(-DCMAKE_SHARED_LINKER_FLAGS=-static-libgcc)
fi

# -----------

case "$1" in
make)
  process_deps
  postproc_deps
  
  mkdir build
  cd build
  
  cm_args+=(-DCMAKE_C_FLAGS_$(upper $tbs_conf)="$c_flags")
  cmake -G "$cm_tools" "${cm_args[@]}" .. || exit 1
  $make || exit 1
  
  cd .. ;;
  
check)
  cd build
  ctest . || exit 1
  cd .. ;;
  
check2)
  curl -sS -o pngsuite.zip http://www.schaik.com/pngsuite/PngSuite-2013jan13.zip > /dev/null || exit 1
  unzip -o pngsuite.zip -d pngsuite || exit 1
  cd pngsuite
  
  # test all except x*.png; invalid files
  echo "" > CTestTestfile.cmake
  for pic in *.png; do
    [ ${pic:0:1} == "x" ] || echo "add_test(pngstest_${pic%.*} \"../build/pngstest\" \"$pic\")" >> CTestTestfile.cmake
  done
  
  ctest -C $tbs_conf
  cd .. ;;
  
clean)
  rm -rf pngsuite
  rm -rf deps
  rm -rf build_deps
  rm -rf build ;;

list) echo $list ;;
list_bin) echo $l_bin ;;
list_inc) echo $l_inc ;;
list_slib) echo $l_slib ;;
list_dlib) echo $l_dlib ;;

*) echo "Unknown command $1"
   exit 1 ;;
esac

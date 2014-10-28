#!/bin/bash
# call this from repo root: ./scripts/make_drone.io
# add this to the artifact list:
# out/libpng-x64.tar.gz
# out/libpng-x86.tar.gz

mkdir out

./scripts/thumbs.sh make
./scripts/thumbs.sh check
./scripts/thumbs.sh check2
objdump -f build/*.so | grep ^architecture
ldd build/*.so
tar -zcf out/libpng-x64.tar.gz --transform 's/.\/build\///;s/.\///' $(./thumbs.sh list)
./scripts/thumbs.sh clean

sudo apt-get -y update > /dev/null
sudo apt-get -y install gcc-multilib > /dev/null

export tbs_arch=x86
./scripts/thumbs.sh make
./scripts/thumbs.sh check
./scripts/thumbs.sh check2
objdump -f build/*.so | grep ^architecture
ldd build/*.so
tar -zcf out/libpng-x86.tar.gz --transform 's/.\/build\///;s/.\///' $(./thumbs.sh list)
./scripts/thumbs.sh clean

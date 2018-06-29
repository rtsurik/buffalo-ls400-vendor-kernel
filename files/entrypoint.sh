#!/usr/bin/env bash

BUFFALO_KERNEL_VER="3.3.4"
LINARO_GCC_VER="4.9.4-2017.01"
BUILD_DIR="/build"
OUTPUT_DIR="/out"

cd ${BUILD_DIR}/linux-${BUFFALO_KERNEL_VER}

export ARCH="arm"
export CROSS_COMPILE="${BUILD_DIR}/gcc-linaro-${LINARO_GCC_VER}-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-"

# Build all
make -j4 all

# Build uImage and modules
make uImage
make modules

# Install kernel and modules to the output dir
mkdir -p ${OUTPUT_DIR}/{boot,lib}
INSTALL_MOD_PATH=${OUTPUT_DIR} make modules_install
cp -a ./arch/arm/boot/uImage ${OUTPUT_DIR}/boot/uImage.buffalo

# Chown the output dir contents
chown -R ${UID}:${GID} ${OUTPUT_DIR}

# Build an empty initrd image
mkdir -p /tmp/build-initrd
cd /tmp/build-initrd
echo . | cpio -ov > initrd.cpio
gzip initrd.cpio
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x00000000 \
    -n "Buffalo LS421DE empty initrd" \
    -d initrd.cpio.gz ${OUTPUT_DIR}/boot/initrd.buffalo

#!/usr/bin/env bash

## This is a simple script for building Buffalo's 3.3.4 kernel in a Docker container
##
## (C) 2018 Rustam Tsurik

## Download URLs
##
BUFFALO_KERNEL_VER="3.3.4"
BUFFALO_KERNEL_NAME="linux-${BUFFALO_KERNEL_VER}-buffalo.tar.bz2"
BUFFALO_KERNEL_URL="http://buffalo.jp/php/los.php?to=gpl/storage/ls400/110/${BUFFALO_KERNEL_NAME}"
BUFFALO_KERNEL_MD5="b7cfe82957b600c599b8f9a878a889c1"

LINARO_GCC_VER="4.9.4-2017.01"
LINARO_GCC_NAME="gcc-linaro-${LINARO_GCC_VER}-x86_64_arm-linux-gnueabihf.tar.xz"
LINARO_GCC_URL="https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/arm-linux-gnueabihf/${LINARO_GCC_NAME}"
LINARO_GCC_MD5="545af35e13c439cc156dc0881d976463"

KERNEL_CONFIG="buffalo_ls421de_build1_config"

BUILDBOX_IMAGE="buffalo-build:latest"
BUILDBOX_CLEANUP="0"

OUTPUT_TARBALL="buffalo-kernel_${BUFFALO_KERNEL_VER}"

## Color codes
##
RESET='\e[0m'
BOLD='\e[1m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'

## Paths, we need an absolute path for Docker stuff
##
BUILD_PATH="$(cd "$(dirname "$0")"; pwd -P )"
FILES_PATH="${BUILD_PATH}/files"

## Helper functions
##
function download_archive {
    DL_URL=$1
    DL_NAME=$2
    DL_MD5=$3
    DL_WHAT=$4

    echo -en "${GREEN}[*]${RESET} Checking if the ${YELLOW}${BOLD}${DL_WHAT}${RESET} is already downloaded... "
    if [ -f "${FILES_PATH}/${DL_NAME}" ]; then
        echo -e "${GREEN}${BOLD}found${RESET}."  
    else
        echo -e "${RED}${BOLD}not found${RESET}."
        echo -en "${GREEN}[*]${RESET} Downloading from ${DL_URL}... "
        curl -s -L -o "${FILES_PATH}/${DL_NAME}" "${DL_URL}"
        echo -e "${GREEN}${BOLD}done${RESET}."
    fi

    echo -en "${GREEN}[*]${RESET} Verifying ${DL_WHAT} MD5 checksum... "
    NEW_DL_MD5=$(md5sum "${FILES_PATH}/${DL_NAME}" | awk '{print $1}')

    if [[ "${NEW_DL_MD5}" == "${DL_MD5}" ]] ; then
        echo -e "${GREEN}${BOLD}good${RESET}."
    else
        echo -e "${RED}${BOLD}mismath${RESET}."
        exit 2;
    fi
}

## Let's go
##
echo -e "${BOLD}Building Buffalo kernel v${BUFFALO_KERNEL_VER}.${RESET}\n"

## Download Buffalo kernel sources
##
download_archive ${BUFFALO_KERNEL_URL} ${BUFFALO_KERNEL_NAME} ${BUFFALO_KERNEL_MD5} "kernel sources"

## Download Linaro GCC toolchain
##
download_archive ${LINARO_GCC_URL} $LINARO_GCC_NAME $LINARO_GCC_MD5 "Linaro toolchain"


## Cleanup the old docker image
##
if [[ "${BUILDBOX_CLEANUP}" == "1" ]] ; then
    echo -e "${GREEN}[*]${RESET} Cleaning up the old Docker images for ${YELLOW}${BOLD}${BUILDBOX_IMAGE}${RESET}"
    echo -e "    - Cleaning up containers"
    for container in $(docker ps -qa -f ancestor=${BUILDBOX_IMAGE}); do
        docker rm ${container}
    done
    echo -e "    - Cleaning up images"
    BUILDBOX_IMAGE_ID=$(docker images -q "${BUILDBOX_IMAGE}")
    if [[ -n ${BUILDBOX_IMAGE_ID} ]] ; then
    	docker rmi ${BUILDBOX_IMAGE_ID}
    fi
fi

## Build the Docker image
##
echo -ne "${GREEN}[*]${RESET} Checking if the ${YELLOW}${BOLD}${BUILDBOX_IMAGE}${RESET} Docker image exists..."

BUILDBOX_IMAGE_ID=$(docker images -q "${BUILDBOX_IMAGE}")
if [[ -z ${BUILDBOX_IMAGE_ID} ]] ; then
    echo -e "${RED}${BOLD}missing${RESET}"
    echo -e "${GREEN}[*]${RESET} Building the Docker image"
    docker build --tag ${BUILDBOX_IMAGE} ${BUILD_PATH}
else
	echo -e "${GREEN}${BOLD}found${RESET}"
fi


## Build kernel in a Docker container
##
echo -e "${GREEN}[*]${RESET} Building the kernel in a Docker container"

if [[ ! -f ${FILES_PATH}/${KERNEL_CONFIG} ]] ; then
    echo -e "${GREEN}[*]${RESET} Config file  ${YELLOW}${BOLD}${FILES_PATH}/${KERNEL_CONFIG}${RESET} ${RED}${BOLD}not found${RESET}."
fi

mkdir -p "${BUILD_PATH}/out"
docker run \
    -v "${BUILD_PATH}/out:/out" \
    -v "${FILES_PATH}/${KERNEL_CONFIG}:/build/linux-${BUFFALO_KERNEL_VER}/.config:ro" \
    -e UID=$(id -u) -e GID=$(id -g) \
    --rm \
    $BUILDBOX_IMAGE

## Creating a tarball
##
LOCAL_VERSION=$(grep "^CONFIG_LOCALVERSION=" "${FILES_PATH}/${KERNEL_CONFIG}" |cut -d= -f2|sed 's/"//g;s/^-//')
EPOCH=$(date +%s)

if [[ -z "${LOCAL_VERSION}" ]] ; then
    LOCAL_VERSION="none"
fi

echo -e "${GREEN}[*]${RESET} Creating a tarball with the compiled kernel"

cd "${BUILD_PATH}/out"
tar czf ../${OUTPUT_TARBALL}-${LOCAL_VERSION}_${EPOCH}.tar.gz boot lib

## Clean up the output dir
##
echo -e "${GREEN}[*]${RESET} Cleaning up"
cd .. ; rm -rf "${BUILD_PATH}/out"

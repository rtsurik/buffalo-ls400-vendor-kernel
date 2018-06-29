FROM ubuntu:16.04

RUN mkdir /build

ADD files/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf.tar.xz /build/
ADD files/linux-3.3.4-buffalo.tar.bz2 /build/

COPY files/0001-timeconst.pl-Eliminate-Perl-warning.patch /build/linux-3.3.4/
COPY files/entrypoint.sh /

RUN chmod +x /entrypoint.sh

RUN dpkg --add-architecture i386 ;\
    apt-get update ;\
    apt-get -y upgrade ;\
    apt -y install libc6:i386 libstdc++6:i386 zlib1g:i386 build-essential u-boot-tools cpio

RUN cd /build/linux-3.3.4 ;\
    patch -p1 < ./0001-timeconst.pl-Eliminate-Perl-warning.patch

ENTRYPOINT ["/entrypoint.sh"]

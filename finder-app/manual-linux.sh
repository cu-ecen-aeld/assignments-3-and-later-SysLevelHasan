#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    # echo "Fetching tags to ensure ${KERNEL_VERSION} exists..."
    # git fetch --tags
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here

echo "Building kernel..."
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs

# Copy the built kernel image to OUTDIR so QEMU can find it automatically
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

fi

# TODO: Create necessary base directories

echo "Creating root filesystem structure..."
mkdir -p ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs

mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/sbin
mkdir -p var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    echo "Cloning busybox..."
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}

    echo "Configuring busybox..."
    make distclean
    make defconfig

    # TODO:  Configure busybox
else
    cd busybox
fi


# TODO: Make and install busybox

echo "Building and installing busybox..."
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install


# TODO: Add library dependencies to rootfs

echo "Adding library dependencies..."
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

# Try both possible locations (lib and /usr/aarch64-linux-gnu/lib)
cp -a ${SYSROOT}/usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/ || \
    cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/ || true

cp -a ${SYSROOT}/usr/aarch64-linux-gnu/lib/libm.so.* ${OUTDIR}/rootfs/lib/ || \
    cp -a ${SYSROOT}/lib64/libm.so.* ${OUTDIR}/rootfs/lib64/ || true

cp -a ${SYSROOT}/usr/aarch64-linux-gnu/lib/libresolv.so.* ${OUTDIR}/rootfs/lib/ || \
    cp -a ${SYSROOT}/lib64/libresolv.so.* ${OUTDIR}/rootfs/lib64/ || true

cp -a ${SYSROOT}/usr/aarch64-linux-gnu/lib/libc.so.* ${OUTDIR}/rootfs/lib/ || \
    cp -a ${SYSROOT}/lib64/libc.so.* ${OUTDIR}/rootfs/lib64/ || true



# TODO: Make device nodes
echo "Creating device nodes..."
sudo mkdir -p ${OUTDIR}/rootfs/dev
if [ ! -e ${OUTDIR}/rootfs/dev/null ]; then
    sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
fi
if [ ! -e ${OUTDIR}/rootfs/dev/console ]; then
    sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1
fi


# TODO: Clean and build the writer utility

echo "Building writer application..."
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# Check if writer was built successfully
if [ ! -f "${FINDER_APP_DIR}/writer" ]; then
    echo "Error: writer not built!"
    exit 1
fi

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs

echo "Copying finder scripts and executables..."
mkdir -p ${OUTDIR}/rootfs/home
mkdir -p ${OUTDIR}/rootfs/home/conf

cp ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/conf/username.txt ${OUTDIR}/rootfs/home/conf/username.txt
cp ${FINDER_APP_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/home/conf/assignment.txt
cp ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# Make all copied scripts executable
chmod +x ${OUTDIR}/rootfs/home/*.sh

# TODO: Chown the root directory
echo "Fixing permissions..."
sudo chown -R root:root ${OUTDIR}/rootfs

# TODO: Create initramfs.cpio.gz
echo "Creating initramfs..."
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root | gzip > ${OUTDIR}/initramfs.cpio.gz

echo "Initramfs created successfully at: ${OUTDIR}/initramfs.cpio.gz"
